package com.hopa.capabilities.bridge

import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class BridgeClientTest {
    private lateinit var server: MockWebServer
    private lateinit var base: String

    @Before
    fun start() {
        server = MockWebServer()
        server.start()
        base = server.url("/").toString().trimEnd('/')
    }

    @After
    fun stop() {
        server.shutdown()
    }

    @Test
    fun observe_is_mapped_into_the_shared_tree() = runBlocking {
        server.enqueue(MockResponse().setBody(OBSERVE))
        val client = BridgeClient(base, "token")
        val observation = BridgeObservation.fromJson(
            payload = client.observe(),
            app = "com.hopa.android",
            timestamp = 7,
            id = "obs-7",
        )
        assertEquals("Settings", observation.text)
        assertEquals(1080, observation.screenSize.width)
        assertEquals(2, observation.tree.children.size)
        assertEquals("e1", observation.tree.children[0].ref)
        assertEquals(listOf(40, 200, 400, 280), observation.tree.children[0].bounds)
        assertTrue(observation.hash.startsWith("sha256:"))
    }

    @Test
    fun a_401_refreshes_once_and_keeps_the_bridge_shape() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setBody("""{"ok":true,"devices":["phone"]}"""))
        var refreshed = 0
        val client = BridgeClient(base, "old") {
            refreshed += 1
            "new"
        }
        val who = client.whoami()

        assertEquals(1, refreshed)
        assertEquals("Bearer old", server.takeRequest().getHeader("Authorization"))
        assertEquals("Bearer new", server.takeRequest().getHeader("Authorization"))
        assertEquals("phone", who["devices"]!!.jsonArray[0].jsonPrimitive.content)
    }

    @Test
    fun an_error_never_prints_the_token_or_the_base_url() = runBlocking {
        server.enqueue(
            MockResponse().setResponseCode(500).setBody("boom secret-token at $base"),
        )
        val client = BridgeClient(base, "secret-token")
        val message = try {
            client.observe()
            "no error"
        } catch (error: BridgeException) {
            error.message.orEmpty()
        }
        assertFalse(message.contains("secret-token"))
        assertFalse(message.contains(base))
        assertTrue(message.contains("<token>"))
    }

    @Test
    fun pairing_returns_the_token_pair() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"token":"t1","refresh":"r1","expires_in":43200}""",
            ),
        )
        val session = BridgeClient(base, "").pair("123456")

        assertEquals("t1", session.token)
        assertEquals("r1", session.refresh)
        assertEquals(43_200L, session.expiresIn)
        assertEquals("""{"code":"123456"}""", server.takeRequest().body.readUtf8())
    }

    @Test
    fun apps_are_parsed_and_labels_fall_back_to_the_bundle() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"apps":[{"bundle":"com.example","label":"Example"},""" +
                    """{"bundle":"com.other","label":"com.other"}]}""",
            ),
        )
        val apps = BridgeClient(base, "token").apps()
        assertEquals(listOf("com.example", "com.other"), apps.map { it.packageName })
        assertEquals("Example", apps[0].label)
    }

    private companion object {
        val OBSERVE = """
            {"text":"Settings","width":1080,"height":2400,"nodes":[
              {"ref":"e1","text":"Settings","description":"","id":"","type":"android.widget.TextView",
               "bounds":[40,200,400,280],"clickable":true},
              {"ref":"e2","text":"","description":"Search","id":"","type":"android.widget.EditText",
               "bounds":[40,300,1040,380],"clickable":true}
            ]}
        """.trimIndent()
    }
}
