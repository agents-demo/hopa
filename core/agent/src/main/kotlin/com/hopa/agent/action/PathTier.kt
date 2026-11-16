package com.hopa.agent.action

/**
 * The four ways an action can reach an app, cheapest and least disruptive first.
 *
 * `api` is a system or app API, `intent` is a URI or app intent, `uia` is the
 * accessibility/UI Automation tree, and `input` is coordinates and keystrokes.
 */
enum class PathTier(val wire: String) {
    API("api"),
    INTENT("intent"),
    UIA("uia"),
    INPUT("input"),
}
