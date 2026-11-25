package com.hopa.app.pair

import com.hopa.backend.crypto.KeyWrap
import com.hopa.backend.pairing.AdmissionLink
import com.hopa.backend.pairing.AdmissionLinks
import com.hopa.backend.pairing.BackendPairing
import com.hopa.backend.pairing.X25519Keys
import com.hopa.contracts.json.HopaJson
import com.hopa.stores.AppSettings
import com.hopa.stores.SettingsRepository
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

@OptIn(ExperimentalCoroutinesApi::class)
class VouchViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeEach
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `a scanned link resolves to a confirm state with the PC name and fingerprint`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys)))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()

            assertEquals("Studio", viewModel.state.value.confirm?.name)
            assertEquals("abcd1234", viewModel.state.value.confirm?.fingerprint)
            assertNull(viewModel.state.value.error)
            assertFalse(viewModel.state.value.vouched)
            assertEquals("/v1/pair/pending/resolve", server.takeRequest().path)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `confirm posts the vouch and the wrap unwraps to the known content key`() = runTest(dispatcher) {
        val keys = keys()
        val key = contentKey()
        val server = server(
            MockResponse().setResponseCode(200).setBody(resolveResponse(keys)),
            MockResponse().setResponseCode(200).setBody("""{"sessionId":"sid","householdId":"h1","memberId":"m1"}"""),
        )
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, key, "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()
            viewModel.confirm()
            advanceUntilIdle()

            assertTrue(viewModel.state.value.vouched)

            assertEquals("/v1/pair/pending/resolve", server.takeRequest().path)
            val vouch = server.takeRequest()
            assertEquals("/v1/pair/vouch", vouch.path)
            assertEquals("Bearer at1", vouch.getHeader("Authorization"))

            val body = HopaJson.element.parseToJsonElement(vouch.body.readUtf8()).jsonObject
            assertEquals("s1", body["sessionSecret"]?.jsonPrimitive?.content)
            val wrappedKey = body["wrappedKey"]?.jsonPrimitive?.content.orEmpty()
            assertTrue(wrappedKey.isNotBlank())

            val wrapped = Base64.getUrlDecoder().decode(wrappedKey)
            val unwrapped = KeyWrap.unwrapByDevice(wrapped, keys.phonePublicKey, keys.pcPrivateKey)
            assertArrayEquals(key, unwrapped)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `an expired session stays on the scan screen with a plain message`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys, "expired")))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()

            assertEquals("This pairing session has expired.", viewModel.state.value.error)
            assertNull(viewModel.state.value.confirm)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `a claimed session stays on the scan screen with a plain message`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys, "claimed")))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()

            assertEquals("This pairing session has already been claimed.", viewModel.state.value.error)
            assertNull(viewModel.state.value.confirm)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `an already vouched session stays on the scan screen with a plain message`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys, "vouched")))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()

            assertEquals(
                "This pairing session was already approved on another phone.",
                viewModel.state.value.error,
            )
            assertNull(viewModel.state.value.confirm)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `an unknown secret surfaces E_SCHEMA and stays on the scan screen`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(
            MockResponse().setResponseCode(400).setBody("""{"code":"E_SCHEMA","message":"unknown pairing session"}"""),
        )
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()

            assertEquals("E_SCHEMA", viewModel.state.value.error)
            assertNull(viewModel.state.value.confirm)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `the paste path reaches the same confirm state`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys)))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey(), "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            val text = AdmissionLinks.encode(AdmissionLink("s1", gateway(server)))
            viewModel.resolvePasted(text)
            advanceUntilIdle()

            assertEquals("Studio", viewModel.state.value.confirm?.name)
            assertEquals("abcd1234", viewModel.state.value.confirm?.fingerprint)
            assertNull(viewModel.state.value.error)
            assertEquals("/v1/pair/pending/resolve", server.takeRequest().path)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `a phone with no content key is refused with the clear message and posts nothing`() = runTest(dispatcher) {
        val keys = keys()
        val server = server(MockResponse().setResponseCode(200).setBody(resolveResponse(keys)))
        try {
            val viewModel = VouchViewModel(
                settings = FakeSettings(keys.phonePrivateKey, contentKey = ByteArray(0), accessToken = "at1"),
                pairing = { BackendPairing(it, dispatcher = dispatcher) },
            )

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()
            viewModel.confirm()
            advanceUntilIdle()

            assertEquals(
                "This phone isn't connected yet. Sign in on the phone that set up the account.",
                viewModel.state.value.error,
            )
            assertNull(viewModel.state.value.confirm)
            assertFalse(viewModel.state.value.vouched)
            // Only the resolve was posted; the vouch never reached the server.
            assertEquals(1, server.requestCount)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `no request body or message carries the raw private or content key`() = runTest(dispatcher) {
        val keys = keys()
        val key = contentKey()
        val server = server(
            MockResponse().setResponseCode(200).setBody(resolveResponse(keys)),
            MockResponse().setResponseCode(400).setBody("""{"code":"E_SCHEMA","message":"already vouched"}"""),
        )
        try {
            val settings = FakeSettings(keys.phonePrivateKey, key, "at1")
            val viewModel = VouchViewModel(settings, pairing = { BackendPairing(it, dispatcher = dispatcher) })
            val privateKeyText = Base64.getEncoder().encodeToString(keys.phonePrivateKey)
            val contentKeyText = Base64.getEncoder().encodeToString(key)

            viewModel.resolve(AdmissionLink("s1", gateway(server)))
            advanceUntilIdle()
            viewModel.confirm()
            advanceUntilIdle()

            assertEquals("E_SCHEMA", viewModel.state.value.error)

            server.takeRequest() // the resolve
            val vouchBody = server.takeRequest().body.readUtf8()
            assertFalse(vouchBody.contains(privateKeyText))
            assertFalse(vouchBody.contains(contentKeyText))

            val message = viewModel.state.value.error.orEmpty()
            assertFalse(message.contains(privateKeyText))
            assertFalse(message.contains(contentKeyText))
        } finally {
            server.shutdown()
        }
    }

    private fun keys(): Keys {
        val pcPrivate = X25519Keys.generatePrivateKey()
        val phonePrivate = X25519Keys.generatePrivateKey()
        return Keys(
            pcPrivateKey = pcPrivate,
            pcPublicKey = X25519Keys.publicKeyBytes(pcPrivate),
            phonePrivateKey = phonePrivate,
            phonePublicKey = X25519Keys.publicKeyBytes(phonePrivate),
        )
    }

    private fun contentKey(): ByteArray = ByteArray(32) { (it + 1).toByte() }

    private fun resolveResponse(keys: Keys, state: String = "pending"): String {
        val publicKey = Base64.getUrlEncoder().withoutPadding().encodeToString(keys.pcPublicKey)
        return "{\"sessionId\":\"sid\",\"state\":\"$state\",\"name\":\"Studio\",\"platform\":\"windows\"," +
            "\"publicKey\":\"$publicKey\",\"fingerprint\":\"abcd1234\",\"expiresAt\":\"2026-11-23T00:05:00Z\"}"
    }

    private fun server(vararg responses: MockResponse): MockWebServer = MockWebServer().apply {
        responses.forEach(::enqueue)
        start()
    }

    /** MockWebServer speaks plain HTTP, so the socket scheme is `ws`. */
    private fun gateway(server: MockWebServer) = "ws://${server.hostName}:${server.port}/v1/gateway"

    private data class Keys(
        val pcPrivateKey: ByteArray,
        val pcPublicKey: ByteArray,
        val phonePrivateKey: ByteArray,
        val phonePublicKey: ByteArray,
    )

    private class FakeSettings(
        privateKey: ByteArray,
        contentKey: ByteArray,
        private val accessToken: String,
    ) : SettingsRepository {
        private val flow = MutableStateFlow(AppSettings())
        override val settings: Flow<AppSettings> = flow
        private val privateKey = Base64.getEncoder().encodeToString(privateKey)
        private val contentKey = Base64.getEncoder().encodeToString(contentKey)

        override suspend fun update(transform: (AppSettings) -> AppSettings) {
            flow.value = transform(flow.value)
        }

        override suspend fun modelKey(): String = ""
        override suspend fun hasModelKey(): Boolean = false
        override suspend fun setModelKey(value: String) = Unit
        override suspend fun bridgeToken(): String = ""
        override suspend fun setBridgeToken(value: String) = Unit
        override suspend fun bridgeRefresh(): String = ""
        override suspend fun setBridgeRefresh(value: String) = Unit
        override suspend fun backendAccessToken(): String = accessToken
        override suspend fun setBackendAccessToken(value: String) = Unit
        override suspend fun backendRefreshToken(): String = ""
        override suspend fun setBackendRefreshToken(value: String) = Unit
        override suspend fun backendPrivateKey(): String = privateKey
        override suspend fun setBackendPrivateKey(value: String) = Unit
        override suspend fun backendContentKey(): String = contentKey
        override suspend fun setBackendContentKey(value: String) = Unit
        override suspend fun clearBackend() = Unit
    }
}
