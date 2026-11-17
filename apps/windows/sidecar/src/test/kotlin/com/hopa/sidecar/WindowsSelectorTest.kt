package com.hopa.sidecar

import com.hopa.contracts.wire.Action
import com.hopa.agent.action.PathTier
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** The Windows path selector: intent first when a page has a URI. */
class WindowsSelectorTest {
    private val selector = WindowsPathSelector()

    @Test
    fun a_settings_alias_becomes_an_intent() {
        val planned = selector.choose(Action(kind = "ui.launch", app = "wifi"))

        assertEquals("system.openLink", planned.action.kind)
        assertEquals("ms-settings:network-wifi", planned.action.url)
        assertNull(planned.action.app)
        assertEquals(PathTier.INTENT, planned.tier)
    }

    @Test
    fun an_explicit_uri_keeps_its_page() {
        val planned = selector.choose(Action(kind = "ui.launch", app = "ms-settings:display"))

        assertEquals("system.openLink", planned.action.kind)
        assertEquals("ms-settings:display", planned.action.url)
        assertEquals(PathTier.INTENT, planned.tier)
    }

    @Test
    fun a_real_app_stays_a_uia_launch() {
        val planned = selector.choose(Action(kind = "ui.launch", app = "notepad"))

        assertEquals("ui.launch", planned.action.kind)
        assertEquals(PathTier.UIA, planned.tier)
    }

    @Test
    fun a_package_name_is_not_an_alias() {
        val planned = selector.choose(Action(kind = "ui.launch", app = "com.android.settings"))

        assertEquals("ui.launch", planned.action.kind)
        assertEquals(PathTier.UIA, planned.tier)
    }

    @Test
    fun open_link_is_already_an_intent() {
        val planned = selector.choose(Action(kind = "system.openLink", url = "https://example.com"))

        assertEquals(PathTier.INTENT, planned.tier)
        assertEquals("https://example.com", planned.action.url)
    }

    @Test
    fun a_ref_gesture_is_uia_and_coordinates_are_input() {
        assertEquals(
            PathTier.UIA,
            selector.choose(Action(kind = "ui.tap", ref = "e1")).tier,
        )
        assertEquals(
            PathTier.INPUT,
            selector.choose(Action(kind = "ui.tap", x = 10, y = 20)).tier,
        )
        assertEquals(
            PathTier.INPUT,
            selector.choose(Action(kind = "ui.back")).tier,
        )
    }

    @Test
    fun an_app_function_is_api() {
        assertEquals(
            PathTier.API,
            selector.choose(Action(kind = "app.function", app = "notepad", ref = "save")).tier,
        )
    }

    @Test
    fun a_settings_alias_plans_an_intent_then_a_uia_launch() {
        val planned = selector.plan(Action(kind = "ui.launch", app = "wifi"))

        assertEquals(2, planned.size)
        assertEquals(PathTier.INTENT, planned[0].tier)
        assertEquals("system.openLink", planned[0].action.kind)
        assertEquals("ms-settings:network-wifi", planned[0].action.url)
        assertEquals(PathTier.UIA, planned[1].tier)
        assertEquals("ui.launch", planned[1].action.kind)
        assertEquals("wifi", planned[1].action.app)
    }

    @Test
    fun an_unmapped_launch_has_no_intent_to_fall_back_from() {
        val planned = selector.plan(Action(kind = "ui.launch", app = "notepad"))

        assertEquals(1, planned.size)
        assertEquals(PathTier.UIA, planned[0].tier)
    }

    @Test
    fun choose_is_always_the_first_planned_tier() {
        val action = Action(kind = "ui.launch", app = "wifi")
        assertEquals(selector.plan(action).first(), selector.choose(action))
    }
}
