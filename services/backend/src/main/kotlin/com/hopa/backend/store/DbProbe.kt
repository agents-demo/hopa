package com.hopa.backend.store

/** What `/v1/health` may say about the database without holding a connection open. */
fun interface DbProbe {
    fun status(): String

    /** Queue depth for one household, or null when the caller is not authenticated. */
    fun queueDepth(householdId: String): Int? = null

    companion object {
        val Unconfigured = DbProbe { "unconfigured" }
    }
}

class PostgresProbe(private val db: Database) : DbProbe {
    override fun status(): String =
        try {
            db.tenant("00000000-0000-0000-0000-000000000000") { connection ->
                connection.createStatement().use { statement ->
                    statement.executeQuery("select 1").use { rows -> rows.next() }
                }
            }
            "ok"
        } catch (_: Exception) {
            "down"
        }

    override fun queueDepth(householdId: String): Int? =
        try {
            db.tenant(householdId) { connection ->
                connection.createStatement().use { statement ->
                    statement.executeQuery(
                        "select count(*) from tasks " +
                            "where state in ('queued','delivered') and deadline_at > now()",
                    ).use { rows ->
                        rows.next()
                        rows.getInt(1)
                    }
                }
            }
        } catch (_: Exception) {
            null
        }
}
