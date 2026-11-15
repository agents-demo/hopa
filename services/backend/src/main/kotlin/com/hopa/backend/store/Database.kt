package com.hopa.backend.store

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.sql.Connection
import org.flywaydb.core.Flyway

/**
 * The pool and the only two ways to touch SQL.
 *
 * [tenant] sets `hopa.household_id` for the transaction; [token] sets
 * `hopa.token_hash` so a token row can only be read by a caller who already
 * holds that token. Both are `SET LOCAL` (`set_config(..., true)`), so the value
 * cannot leak to the next borrower of a pooled connection. A query outside these
 * helpers sees nothing, because the policies default to deny.
 */
class Database(internal val dataSource: HikariDataSource) : AutoCloseable {
    fun migrate(): Int =
        Flyway.configure()
            .dataSource(dataSource)
            .load()
            .migrate()
            .migrationsExecuted

    fun <T> tenant(householdId: String, block: (Connection) -> T): T =
        transaction(mapOf("hopa.household_id" to householdId), block)

    fun <T> token(tokenHashHex: String, block: (Connection) -> T): T =
        transaction(mapOf("hopa.token_hash" to tokenHashHex), block)

    override fun close() {
        dataSource.close()
    }

    private fun <T> transaction(settings: Map<String, String>, block: (Connection) -> T): T =
        dataSource.connection.use { connection ->
            val previousAutoCommit = connection.autoCommit
            connection.autoCommit = false
            try {
                settings.forEach { (key, value) ->
                    connection.prepareStatement("select set_config(?, ?, true)").use { statement ->
                        statement.setString(1, key)
                        statement.setString(2, value)
                        statement.execute()
                    }
                }
                val result = block(connection)
                connection.commit()
                result
            } catch (problem: Throwable) {
                connection.rollback()
                throw problem
            } finally {
                connection.autoCommit = previousAutoCommit
            }
        }

    companion object {
        internal data class ConnectionInfo(
            val jdbcUrl: String,
            val user: String,
            val password: String,
        )

        fun connect(
            jdbcUrl: String,
            user: String,
            password: String,
            maxPoolSize: Int = 10,
        ): Database {
            val config = HikariConfig().apply {
                this.jdbcUrl = jdbcUrl
                username = user
                this.password = password
                maximumPoolSize = maxPoolSize
                connectionTimeout = 10_000
            }
            return Database(HikariDataSource(config))
        }

        /**
         * Render exports `DATABASE_URL` as `postgres://user:pass@host:port/db`.
         * `JDBC_DATABASE_URL` is the escape hatch for a URL that is already JDBC.
         */
        fun fromEnvironment(env: Map<String, String> = System.getenv()): Database? =
            connectionInfo(env)?.let { connect(it.jdbcUrl, it.user, it.password) }

        internal fun connectionInfo(env: Map<String, String>): ConnectionInfo? {
            env["JDBC_DATABASE_URL"]?.let { jdbcUrl ->
                return ConnectionInfo(
                    jdbcUrl = jdbcUrl,
                    user = env["DATABASE_USER"].orEmpty(),
                    password = env["DATABASE_PASSWORD"].orEmpty(),
                )
            }
            val raw = env["DATABASE_URL"] ?: return null
            val uri = URI(raw)
            val userInfo = uri.rawUserInfo
            val user = userInfo
                ?.substringBefore(":")
                ?.let { URLDecoder.decode(it, StandardCharsets.UTF_8) }
                .orEmpty()
            val password = userInfo
                ?.substringAfter(":", "")
                ?.let { URLDecoder.decode(it, StandardCharsets.UTF_8) }
                .orEmpty()
            val port = if (uri.port == -1) 5432 else uri.port
            return ConnectionInfo(
                jdbcUrl = "jdbc:postgresql://${uri.host}:$port${uri.path}",
                user = user,
                password = password,
            )
        }
    }
}
