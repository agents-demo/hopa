package com.hopa.data.secrets

interface SecretStore {
    suspend fun get(alias: String): String

    suspend fun set(alias: String, value: String)

    suspend fun clear(alias: String)
}
