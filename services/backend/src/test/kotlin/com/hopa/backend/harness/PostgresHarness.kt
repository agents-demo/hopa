package com.hopa.backend.harness

import com.hopa.backend.store.Database
import java.util.UUID
import org.testcontainers.containers.PostgreSQLContainer

/**
 * One Postgres 16 container for the whole test JVM.
 *
 * Migrations run as `hopa_owner`, a NOSUPERUSER NOBYPASSRLS role, so the tables
 * are owned by a role the policies actually apply to — that is what makes
 * `FORCE ROW LEVEL SECURITY` a real assertion rather than decoration. The app
 * under test connects as `hopa_app`, a second non-superuser role. The container
 * superuser is used only to create the two roles.
 */
object PostgresHarness {
    private const val NO_HOUSEHOLD = "00000000-0000-0000-0000-000000000000"

    private val container by lazy {
        PostgreSQLContainer<Nothing>("postgres:16-alpine").apply {
            withDatabaseName("hopa")
            withUsername("postgres")
            withPassword("postgres")
            start()
        }
    }

    private var prepared = false

    private val admin: Database by lazy {
        Database.connect(container.jdbcUrl, "postgres", "postgres").also { prepare(it) }
    }

    private val owner: Database by lazy {
        adminDatabase()
        Database.connect(container.jdbcUrl, "hopa_owner", "hopa_owner")
    }

    private val app: Database by lazy {
        adminDatabase()
        Database.connect(container.jdbcUrl, "hopa_app", "hopa_app")
    }

    fun adminDatabase(): Database = admin

    /** The role that owns the tables: the deploy role on Render. */
    fun ownerDatabase(): Database = owner

    /** The role the application connects as. */
    fun appDatabase(): Database = app

    private fun prepare(admin: Database) {
        if (prepared) return
        synchronized(this) {
            if (prepared) return
            admin.tenant(NO_HOUSEHOLD) { connection ->
                connection.createStatement().use { statement ->
                    statement.execute(
                        """
                        DO $$ BEGIN
                          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hopa_owner') THEN
                            CREATE ROLE hopa_owner LOGIN PASSWORD 'hopa_owner' NOSUPERUSER NOBYPASSRLS;
                          END IF;
                          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hopa_app') THEN
                            CREATE ROLE hopa_app LOGIN PASSWORD 'hopa_app' NOSUPERUSER NOBYPASSRLS;
                          END IF;
                        END $$;
                        """.trimIndent(),
                    )
                    statement.execute("GRANT USAGE, CREATE ON SCHEMA public TO hopa_owner")
                    statement.execute("GRANT USAGE ON SCHEMA public TO hopa_app")
                }
            }

            Database.connect(container.jdbcUrl, "hopa_owner", "hopa_owner").use { owner ->
                owner.migrate()
            }

            admin.tenant(NO_HOUSEHOLD) { connection ->
                connection.createStatement().use { statement ->
                    statement.execute(
                        "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hopa_app",
                    )
                    statement.execute(
                        "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hopa_app",
                    )
                }
            }
            prepared = true
        }
    }
}

fun newHousehold(): String = UUID.randomUUID().toString()

fun newDevice(): String = UUID.randomUUID().toString()

/** A household with one owner member and one device, inserted under its own tenant. */
fun seedHousehold(db: Database, household: String, device: String, member: String) {
    db.tenant(household) { connection ->
        connection.prepareStatement("insert into households(id, name) values (?::uuid, 'test')").use {
            it.setString(1, household)
            it.executeUpdate()
        }
        connection.prepareStatement(
            "insert into members(id, household_id, role, display_name) " +
                "values (?::uuid, ?::uuid, 'owner', 'Test')",
        ).use {
            it.setString(1, member)
            it.setString(2, household)
            it.executeUpdate()
        }
        connection.prepareStatement(
            "insert into devices(id, household_id, member_id, platform, name) " +
                "values (?::uuid, ?::uuid, ?::uuid, 'android', 'Pixel')",
        ).use {
            it.setString(1, device)
            it.setString(2, household)
            it.setString(3, member)
            it.executeUpdate()
        }
    }
}
