package com.hopa.capabilities.system

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import android.provider.CalendarContract
import com.hopa.core.ports.SystemPort

class AndroidSystemPort(
    private val context: Context,
) : SystemPort {
    override suspend fun setAlarm(hour: Int, minute: Int, label: String) {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM)
            .putExtra(AlarmClock.EXTRA_HOUR, hour)
            .putExtra(AlarmClock.EXTRA_MINUTES, minute)
            .putExtra(AlarmClock.EXTRA_MESSAGE, label)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    override suspend fun addEvent(title: String, startMillis: Long, endMillis: Long) {
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.Events.TITLE, title)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    override suspend fun openLink(url: String) {
        start(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    override suspend fun share(text: String) {
        val send = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, text)
        start(Intent.createChooser(send, "Share"))
    }

    override suspend fun sendMessage(target: String, text: String) {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$target"))
            .putExtra("sms_body", text)
        start(intent)
    }

    override suspend fun call(number: String) {
        start(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")))
    }

    override suspend fun delete(query: String) {
        throw UnsupportedOperationException("Android has no generic delete intent")
    }

    override suspend fun uninstall(packageName: String) {
        start(Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName")))
    }

    private fun start(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
