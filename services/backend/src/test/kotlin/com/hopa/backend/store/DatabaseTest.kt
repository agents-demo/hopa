package com.hopa.backend.store

import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class DatabaseTest {
    @Test
    fun `migrations apply from empty and a second run is a no-op`() {
        val db = PostgresHarness.adminDatabase()

        val first = db.migrate()

        assertEquals(0, first)
        assertEquals(0, db.migrate())
    }

    @Test
    fun `a connection without a household setting sees no rows`() {
        val db = PostgresHarness.appDatabase()
        val household = newHousehold()
        seedHousehold(db, household, newDevice(), UUID.randomUUID().toString())

        val visible = db.dataSource.connection.use { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery("select count(*) from devices").use { rows ->
                    rows.next()
                    rows.getInt(1)
                }
            }
        }

        assertEquals(0, visible)
    }

    @Test
    fun `a tenant transaction sees only its household`() {
        val db = PostgresHarness.appDatabase()
        val home = newHousehold()
        seedHousehold(db, home, newDevice(), UUID.randomUUID().toString())

        val count = db.tenant(home) { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery("select count(*) from devices").use { rows ->
                    rows.next()
                    rows.getInt(1)
                }
            }
        }

        assertEquals(1, count)
    }

    @Test
    fun `a postgres url from the environment becomes a jdbc url`() {
        val info = Database.connectionInfo(
            mapOf("DATABASE_URL" to "postgres://u:p%40ss@db.example:5432/hopa"),
        )

        assertNotNull(info)
        assertEquals("jdbc:postgresql://db.example:5432/hopa", info!!.jdbcUrl)
        assertEquals("u", info.user)
        assertEquals("p@ss", info.password)
    }

    @Test
    fun `a connection string keeps its query and a literal plus in the password`() {
        val info = Database.connectionInfo(
            mapOf(
                "DATABASE_URL" to "postgres://u:p+ss%40x@db.example:5432/hopa?sslmode=require",
            ),
        )

        assertNotNull(info)
        assertEquals("jdbc:postgresql://db.example:5432/hopa?sslmode=require", info!!.jdbcUrl)
        assertEquals("p+ss@x", info.password)
    }
}
