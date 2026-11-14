package com.hopa.capabilities.accessibility

import android.view.accessibility.AccessibilityNodeInfo
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.observation.ObservationHasher

class NodeTreeReader(
    private val service: HopaAccessibilityService,
    private val maxNodes: Int = 400,
    private val maxText: Int = 6_000,
) {
    val refs: MutableMap<String, AccessibilityNodeInfo> = mutableMapOf()
    private var counter = 0
    private var truncated = false
    private var focusedRef = ""
    private val texts = mutableListOf<String>()

    fun read(): Observation {
        refs.clear()
        counter = 0
        truncated = false
        focusedRef = ""
        texts.clear()
        val root = service.activeRoot()
        val tree = if (root == null) {
            ObservationNode(type = "root")
        } else {
            convert(root)
        }
        val metrics = service.resources.displayMetrics
        val observation = Observation(
            id = "obs-${System.currentTimeMillis()}",
            timestamp = System.currentTimeMillis(),
            displayId = service.display?.displayId ?: 0,
            windowId = root?.windowId?.toString() ?: "active",
            rotation = service.display?.rotation ?: 0,
            density = metrics.density,
            screenSize = ScreenSize(metrics.widthPixels, metrics.heightPixels),
            focus = focusedRef,
            text = texts.joinToString("\n").take(maxText),
            tree = tree,
            app = root?.packageName?.toString() ?: "",
            truncated = truncated,
        )
        return observation.copy(hash = ObservationHasher.hash(observation))
    }

    private fun convert(info: AccessibilityNodeInfo): ObservationNode {
        if (counter >= maxNodes) {
            truncated = true
            return ObservationNode(type = "truncated")
        }
        val ref = "e${++counter}"
        if (ref.isNotEmpty()) {
            refs[ref] = info
        }
        val text = info.text?.toString().orEmpty()
        val description = info.contentDescription?.toString().orEmpty()
        if (text.isNotEmpty()) {
            texts += text
        }
        if (description.isNotEmpty() && description != text) {
            texts += description
        }
        if (info.isFocused && ref.isNotEmpty()) {
            focusedRef = ref
        }
        val children = mutableListOf<ObservationNode>()
        for (index in 0 until info.childCount) {
            if (counter >= maxNodes) {
                truncated = true
                break
            }
            val child = info.getChild(index) ?: continue
            children += convert(child)
        }
        val bounds = android.graphics.Rect()
        info.getBoundsInScreen(bounds)
        return ObservationNode(
            ref = ref,
            type = info.className?.toString()?.substringAfterLast('.') ?: "node",
            text = text,
            description = description,
            id = info.viewIdResourceName.orEmpty(),
            bounds = listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
            clickable = info.isClickable,
            enabled = info.isEnabled,
            checked = info.isChecked,
            scrollable = info.isScrollable,
            visible = info.isVisibleToUser,
            focused = info.isFocused,
            children = children,
        )
    }
}
