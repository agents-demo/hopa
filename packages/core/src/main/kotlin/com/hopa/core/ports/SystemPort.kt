package com.hopa.core.ports

interface SystemPort {
    suspend fun setAlarm(hour: Int, minute: Int, label: String)

    suspend fun addEvent(title: String, startMillis: Long, endMillis: Long)

    suspend fun openLink(url: String)

    suspend fun share(text: String)

    suspend fun sendMessage(target: String, text: String)

    suspend fun call(number: String)

    suspend fun delete(query: String)

    suspend fun uninstall(packageName: String)
}
