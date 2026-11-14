package com.hopa.core.json

import kotlinx.serialization.json.Json

object HopaJson {
    val element: Json = Json {
        ignoreUnknownKeys = false
        explicitNulls = false
        encodeDefaults = true
        isLenient = false
    }

    val pretty: Json = Json {
        ignoreUnknownKeys = false
        explicitNulls = false
        encodeDefaults = true
        isLenient = false
        prettyPrint = true
    }
}
