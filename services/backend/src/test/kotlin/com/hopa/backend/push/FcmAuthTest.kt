package com.hopa.backend.push

import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FcmAuthTest {
    private fun keyPair() = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()

    private fun pem(key: PrivateKey): String =
        "-----BEGIN PRIVATE KEY-----\n" +
            Base64.getMimeEncoder(64, "\n".toByteArray()).encodeToString(key.encoded) +
            "\n-----END PRIVATE KEY-----\n"

    private fun credentials(key: PrivateKey): String = buildJsonObject {
        put("client_email", "sa@hopa.test")
        put("private_key", pem(key))
        put("token_uri", "https://oauth2.example/token")
    }.toString()

    @Test
    fun `claims name the firebase scope and the token uri`() {
        val auth = ServiceAccountFcmAuth(credentials(keyPair().private))

        val claims = auth.claims(1_700_000_000)

        assertEquals("sa@hopa.test", claims.iss)
        assertEquals("https://www.googleapis.com/auth/firebase.messaging", claims.scope)
        assertEquals("https://oauth2.example/token", claims.aud)
        assertEquals(1_700_000_000, claims.iat)
        assertEquals(1_700_003_600, claims.exp)
    }

    @Test
    fun `the assertion is a signed three part jwt`() {
        val pair = keyPair()
        val auth = ServiceAccountFcmAuth(credentials(pair.private))

        val assertion = auth.assertion(1_700_000_000)
        val parts = assertion.split(".")

        assertEquals(3, parts.size)
        val header = Json.parseToJsonElement(decode(parts[0])).jsonObject
        assertEquals("RS256", header["alg"]!!.jsonPrimitive.content)
        assertEquals("JWT", header["typ"]!!.jsonPrimitive.content)
        val payload = Json.parseToJsonElement(decode(parts[1])).jsonObject
        assertEquals("sa@hopa.test", payload["iss"]!!.jsonPrimitive.content)

        val verifier = Signature.getInstance("SHA256withRSA").apply {
            initVerify(pair.public)
            update("${parts[0]}.${parts[1]}".toByteArray(Charsets.UTF_8))
        }
        val key = KeyFactory.getInstance("RSA")
            .generatePrivate(PKCS8EncodedKeySpec(pair.private.encoded))
        assertEquals("RSA", key.algorithm)
        assertTrue(verifier.verify(Base64.getUrlDecoder().decode(parts[2])))
    }

    private fun decode(part: String): String =
        String(Base64.getUrlDecoder().decode(part), Charsets.UTF_8)
}
