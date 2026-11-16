package com.hopa.backend.push

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class FcmSenderTest {
    @Test
    fun `a stalled endpoint is abandoned inside the timeout`() {
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.executor = Executors.newCachedThreadPool { runnable ->
            Thread(runnable).apply { isDaemon = true }
        }
        // Never answers: the client has to give up on its own.
        server.createContext("/") { Thread.sleep(30_000) }
        server.start()
        val caller = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable).apply { isDaemon = true }
        }
        try {
            val sender = FcmSender(
                projectId = "hopa-test",
                baseUrl = "http://127.0.0.1:${server.address.port}",
                auth = StaticFcmAuth("test-token"),
                timeoutMs = 300,
            )

            val started = System.nanoTime()
            val pending = caller.submit(
                Callable { sender.send("fcm-token", mapOf("taskId" to "t", "traceId" to "x")) },
            )
            val outcome = try {
                pending.get(5, TimeUnit.SECONDS)
            } catch (_: TimeoutException) {
                null
            }
            val elapsedMs = (System.nanoTime() - started) / 1_000_000

            assertNotNull("send did not return inside ${elapsedMs}ms", outcome)
            assertEquals(PushOutcome.Retryable, outcome)
        } finally {
            server.stop(0)
            caller.shutdownNow()
        }
    }
}
