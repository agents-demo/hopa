package com.hopa.backend.harness

import com.hopa.backend.store.Database
import java.util.UUID
import org.testcontainers.containers.PostgreSQLContainer

/**
 * One Postgres 16 container for the whole test JVM.
 *
 * Flyway and role creation run as the container superuser; the app code under
 * test connects as `hopa_app`, which is `NOSUPERUSER NOBYPASSRLS` so the row
 * level policies actually apply. Testing as `postgres` would bypass them and
 * make every isolation assertion a lie.
 */
object PostgresHarness {
    private val container by lazy {
        PostgreSQLContainer<Nothing>("postgres:16-alpine").apply {
            withDatabaseName("hopa")
            withUsername("postgres")
            withPassword("postgres")
            start()
        }
    }

    private var prepared = false

    fun adminDatabase(): Database {
        val db = Database.connect(container.jdbcUrl, container.username, container.password)
        prepare(db)
        return db
    }

    fun appDatabase(): Database {
        adminDatabase()
        return Database.connect(container.jdbcUrl, "hopa_app", "hopa_app")
    }

    private fun prepare(admin: Database) {
        if (prepared) return
        synchronized(this) {
            if (prepared) return
            admin.migrate()
            admin.tenant("00000000-0000-0000-0000-000000000000") { connection ->
                connection.createStatement().use { statement ->
                    statement.execute(
                        """
                        DO $$ BEGIN
                          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hopa_app') THEN
                            CREATE ROLE hopa_app LOGIN PASSWORD 'hopa_app' NOSUPERUSER NOBYPASSRLS;
                          END IF;
                        END $$;
                        """.trimIndent(),
                    )
                    statement.execute("GRANT USAGE ON SCHEMA public TO hopa_app")
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
