package com.hopa.sidecar.device

import com.hopa.contracts.ports.SystemPort

/**
 * The Windows system port: the one call that exists today is `openLink`, which
 * opens a URI through the host (and is what turns a settings page into an
 * intent). Everything else refuses honestly instead of pretending.
 */
class HostSystem(private val device: HostDevice) : SystemPort {
    override suspend fun openLink(url: String) {
        device.openLink(url)
    }

    override suspend fun setAlarm(hour: Int, minute: Int, label: String) = unsupported("alarm")

    override suspend fun addEvent(title: String, startMillis: Long, endMillis: Long) =
        unsupported("calendar")

    override suspend fun share(text: String) = unsupported("share")

    override suspend fun sendMessage(target: String, text: String) = unsupported("message")

    override suspend fun call(number: String) = unsupported("call")

    override suspend fun delete(query: String) = unsupported("delete")

    override suspend fun uninstall(packageName: String) = unsupported("uninstall")

    private fun unsupported(what: String): Nothing =
        throw UnsupportedOperationException("Windows has no $what port yet")
}
