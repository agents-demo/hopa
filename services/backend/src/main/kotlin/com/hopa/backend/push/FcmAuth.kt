package com.hopa.backend.push

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

fun interface FcmAuth {
    fun bearerToken(): String
}

class StaticFcmAuth(private val token: String) : FcmAuth {
    override fun bearerToken(): String = token
}

data class JwtClaims(
    val iss: String,
    val scope: String,
    val aud: String,
    val iat: Long,
    val exp: Long,
)

/**
 * The service-account flow: sign an RS256 assertion, exchange it for an OAuth
 * token, cache that token until a minute before it expires. The private key
 * comes from the environment and is never logged.
 */
class ServiceAccountFcmAuth(
    credentialsJson: String,
    private val clock: () -> Long = System::currentTimeMillis,
    private val http: HttpClient = HttpClient.newHttpClient(),
) : FcmAuth {
    private val credentials = Json.parseToJsonElement(credentialsJson).jsonObject
    private val clientEmail = credentials["client_email"]!!.jsonPrimitive.content
    private val privateKeyPem = credentials["private_key"]!!.jsonPrimitive.content
    private val tokenUri = credentials["token_uri"]!!.jsonPrimitive.content

    private var cached: Pair<String, Long>? = null

    fun claims(nowSeconds: Long): JwtClaims = JwtClaims(
        iss = clientEmail,
        scope = SCOPE,
        aud = tokenUri,
        iat = nowSeconds,
        exp = nowSeconds + 3600,
    )

    fun assertion(nowSeconds: Long): String {
        val claims = claims(nowSeconds)
        val header = buildJsonObject {
            put("alg", "RS256")
            put("typ", "JWT")
        }.toString()
        val payload = buildJsonObject {
            put("iss", claims.iss)
            put("scope", claims.scope)
            put("aud", claims.aud)
            put("iat", claims.iat)
            put("exp", claims.exp)
        }.toString()
        val signingInput = base64Url(header.toByteArray(StandardCharsets.UTF_8)) + "." +
            base64Url(payload.toByteArray(StandardCharsets.UTF_8))
        return signingInput + "." + base64Url(sign(signingInput))
    }

    override fun bearerToken(): String {
        val now = clock()
        cached?.let { (token, expiresAt) ->
            if (expiresAt - 60_000 > now) return token
        }

        val form = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" +
            "&assertion=" + assertion(now / 1000)
        val request = HttpRequest.newBuilder(URI.create(tokenUri))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(form))
            .build()
        val response = http.send(request, HttpResponse.BodyHandlers.ofString())
        check(response.statusCode() in 200..299) {
            "service account token exchange failed with ${response.statusCode()}"
        }
        val body = Json.parseToJsonElement(response.body()).jsonObject
        val token = body["access_token"]!!.jsonPrimitive.content
        val expiresIn = body["expires_in"]?.jsonPrimitive?.longOrNull ?: 3600
        cached = token to (now + expiresIn * 1000)
        return token
    }

    private fun sign(input: String): ByteArray {
        val pem = privateKeyPem
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\\s".toRegex(), "")
        val key = KeyFactory.getInstance("RSA")
            .generatePrivate(PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)))
        return Signature.getInstance("SHA256withRSA").run {
            initSign(key)
            update(input.toByteArray(StandardCharsets.UTF_8))
            sign()
        }
    }

    private fun base64Url(bytes: ByteArray): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    private companion object {
        const val SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
    }
}
