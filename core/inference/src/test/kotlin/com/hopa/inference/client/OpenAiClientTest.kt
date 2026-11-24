package com.hopa.inference.client

import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelRequest
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class OpenAiClientTest {
    private lateinit var server: MockWebServer
    private lateinit var base: String

    @BeforeEach
    fun start() {
        server = MockWebServer()
        server.start()
        base = server.url("/").toString().trimEnd('/')
    }

    @AfterEach
    fun stop() {
        server.shutdown()
    }

    @Test
    fun a_key_alone_sends_a_real_chat_completion() = runBlocking {
        server.enqueue(
            MockResponse().setBody(
                """{"choices":[{"message":{"content":"ready"}}],""" +
                    """"usage":{"prompt_tokens":3,"completion_tokens":1,"total_tokens":4}}""",
            ),
        )
        val client = ModelFactory().create(
            provider = "stub",
            endpoint = base,
            apiKey = "sk-test",
            modelName = "deepseek-chat",
        )
        assertFalse(client is DemoModelClient)
        val reply = client.complete(
            ModelRequest(messages = listOf(ModelMessage("user", "ready?"))),
        )
        assertEquals("ready", reply.text)
        assertEquals(4, reply.usage.totalTokens)

        val request = server.takeRequest()
        assertEquals("/chat/completions", request.path)
        assertEquals("Bearer sk-test", request.getHeader("Authorization"))
        val body = request.body.readUtf8()
        assertTrue(body.contains("\"model\":\"deepseek-chat\""))
        // A plain OpenAI-compatible server must not receive reasoning_effort.
        assertFalse(body.contains("reasoning_effort"))
    }

    @Test
    fun a_png_frame_is_sent_as_png_not_jpeg() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))
        val client = OpenAiClient(
            endpoint = base,
            apiKey = "sk-test",
            modelName = "deepseek-v4-flash-vision-exp",
        )
        client.complete(
            ModelRequest(
                messages = listOf(ModelMessage("user", "what word is shown?")),
                images = listOf("iVBORw0KGgoAAAANSUhEUg"),
            ),
        )

        val body = server.takeRequest().body.readUtf8()
        assertTrue(body.contains("data:image/png;base64,iVBORw0KGgo"))
        assertFalse(body.contains("data:image/jpeg;base64,iVBORw0KGgo"))
    }

    @Test
    fun a_jpeg_frame_keeps_the_jpeg_mime() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))
        val client = OpenAiClient(endpoint = base, apiKey = "sk-test", modelName = "m")
        client.complete(
            ModelRequest(
                messages = listOf(ModelMessage("user", "what word is shown?")),
                images = listOf("/9j/4AAQSkZJRg"),
            ),
        )

        assertTrue(server.takeRequest().body.readUtf8().contains("data:image/jpeg;base64,/9j/"))
    }

    @Test
    fun an_endpoint_already_ending_in_chat_completions_is_not_doubled() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"choices":[{"message":{"content":"ok"}}]}"""))
        val client = OpenAiClient(
            endpoint = "$base/chat/completions",
            apiKey = "sk-test",
            modelName = "m",
        )
        client.complete(ModelRequest(messages = listOf(ModelMessage("user", "hi"))))
        assertEquals("/chat/completions", server.takeRequest().path)
    }
}
