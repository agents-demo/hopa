package com.hopa.capabilities.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.Display
import android.view.accessibility.AccessibilityNodeInfo
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.observation.ObservationHasher
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.InstalledApp
import java.io.ByteArrayOutputStream
import kotlin.coroutines.resume
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine

class AccessibilityDevice(
    private val context: Context,
) : DevicePort {
    private var refs: Map<String, AccessibilityNodeInfo> = emptyMap()
    private val producer = com.hopa.core.observation.ObservationProducer()
    private var lastShot = 0L

    override suspend fun observe(): Observation {
        val service = HopaAccessibilityService.instance ?: return offline()
        val reader = NodeTreeReader(service)
        val raw = reader.read()
        refs = reader.refs
        return producer.produce(raw)
    }

    override suspend fun tap(ref: String?, x: Int?, y: Int?) {
        val service = service()
        val dispatcher = GestureDispatcher(service)
        if (ref != null) {
            val node = refs[ref] ?: throw IllegalArgumentException("stale ref $ref")
            if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                delay(250)
                return
            }
            val bounds = android.graphics.Rect()
            node.getBoundsInScreen(bounds)
            dispatcher.tap(bounds.centerX(), bounds.centerY())
            delay(250)
            return
        }
        if (x == null || y == null) {
            throw IllegalArgumentException("tap needs a ref or coordinates")
        }
        dispatcher.tap(x, y)
        delay(250)
    }

    override suspend fun doubleTap(ref: String?, x: Int?, y: Int?) {
        val point = pointFor(ref, x, y)
        GestureDispatcher(service()).doubleTap(point.first, point.second)
        delay(250)
    }

    override suspend fun longPress(ref: String?, x: Int?, y: Int?) {
        val point = pointFor(ref, x, y)
        GestureDispatcher(service()).longPress(point.first, point.second)
        delay(250)
    }

    override suspend fun type(text: String, ref: String?) {
        val node = ref ?: throw IllegalArgumentException("type needs a ref")
        val target = refs[node] ?: throw IllegalArgumentException("stale ref $node")
        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text,
            )
        }
        if (target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
            delay(200)
            return
        }
        val clipboard = context.getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText("HOPA", text))
        if (target.performAction(AccessibilityNodeInfo.ACTION_PASTE)) {
            delay(200)
            return
        }
        throw IllegalStateException("the field refused the text")
    }

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) {
        GestureDispatcher(service()).swipe(fromX, fromY, toX, toY)
        delay(350)
    }

    override suspend fun pressBack() {
        service().performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        delay(250)
    }

    override suspend fun pressHome() {
        service().performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        delay(250)
    }

    override suspend fun launch(packageName: String) {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: throw IllegalArgumentException("no launch intent for $packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        delay(1_500)
    }

    override suspend fun stop(packageName: String) {
        throw UnsupportedOperationException("Android does not allow an app to force-stop another app")
    }

    override suspend fun foreground(): String =
        HopaAccessibilityService.instance?.activeRoot()?.packageName?.toString().orEmpty()

    override suspend fun screenshot(): ByteArray? {
        val now = System.currentTimeMillis()
        if (now - lastShot < 1_000) {
            return null
        }
        val service = runCatching { service() }.getOrNull() ?: return null
        lastShot = now
        return try {
            suspendCancellableCoroutine { continuation ->
                service.takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    context.mainExecutor,
                    object : AccessibilityService.TakeScreenshotCallback {
                        override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                            val bitmap = Bitmap.wrapHardwareBuffer(
                                result.hardwareBuffer,
                                result.colorSpace,
                            )
                            val stream = ByteArrayOutputStream()
                            bitmap?.compress(Bitmap.CompressFormat.JPEG, 88, stream)
                            result.hardwareBuffer.close()
                            continuation.resume(stream.toByteArray())
                        }

                        override fun onFailure(errorCode: Int) {
                            // FLAG_SECURE lands here; say nothing rather than
                            // capture something the app asked to hide.
                            continuation.resume(null)
                        }
                    },
                )
            }
        } catch (error: Exception) {
            null
        }
    }

    override suspend fun apps(): List<InstalledApp> {
        val manager = context.packageManager
        return manager.getInstalledApplications(0)
            .asSequence()
            .filter { it.packageName != context.packageName }
            .map {
                InstalledApp(
                    packageName = it.packageName,
                    label = manager.getApplicationLabel(it).toString(),
                )
            }
            .sortedBy { it.label.lowercase() }
            .toList()
    }

    private fun service(): HopaAccessibilityService {
        if (!AccessibilityState.isEnabled(context)) {
            throw IllegalStateException("accessibility is disabled in Android settings")
        }
        return HopaAccessibilityService.instance
            ?: throw IllegalStateException("accessibility is enabled but not connected yet")
    }

    private fun pointFor(ref: String?, x: Int?, y: Int?): Pair<Int, Int> {
        if (ref != null) {
            val node = refs[ref] ?: throw IllegalArgumentException("stale ref $ref")
            val bounds = android.graphics.Rect()
            node.getBoundsInScreen(bounds)
            return bounds.centerX() to bounds.centerY()
        }
        if (x == null || y == null) {
            throw IllegalArgumentException("a gesture needs a ref or coordinates")
        }
        return x to y
    }

    private fun offline(): Observation {
        val observation = Observation(
            id = "obs-offline",
            timestamp = System.currentTimeMillis(),
            screenSize = ScreenSize(0, 0),
            text = "Accessibility is not enabled. Turn on HOPA in Settings > Accessibility.",
            tree = ObservationNode(type = "root"),
        )
        return observation.copy(hash = ObservationHasher.hash(observation))
    }
}
