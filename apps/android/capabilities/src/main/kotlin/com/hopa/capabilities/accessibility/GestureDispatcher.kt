package com.hopa.capabilities.accessibility

import android.accessibilityservice.GestureDescription
import android.graphics.Path

class GestureDispatcher(
    private val service: HopaAccessibilityService,
) {
    fun tap(x: Int, y: Int) {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        dispatch(path, 40)
    }

    fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, durationMs: Long = 300) {
        val path = Path().apply {
            moveTo(fromX.toFloat(), fromY.toFloat())
            lineTo(toX.toFloat(), toY.toFloat())
        }
        dispatch(path, durationMs)
    }

    private fun dispatch(path: Path, durationMs: Long) {
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
            .build()
        service.dispatchGesture(gesture, null, null)
    }
}
