package com.hopa.capabilities.accessibility

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class HopaAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // The loop reads the tree on demand; events are intentionally ignored.
    }

    override fun onInterrupt() {
        // Nothing to interrupt: actions are short and atomic.
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    fun activeRoot(): AccessibilityNodeInfo? =
        rootInActiveWindow ?: windows.firstOrNull { it.isActive }?.root

    companion object {
        @Volatile
        var instance: HopaAccessibilityService? = null
            private set
    }
}
