package com.hopa.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.hopa.feature.capabilities.CapabilitiesScreen
import com.hopa.ui.theme.HopaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Capabilities: the Act card, what HOPA can use, and Settings as one of the tiles. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi")
class CapabilitiesScreenshotTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun capabilities() {
        compose.setContent {
            HopaTheme {
                CapabilitiesScreen(
                    records = 79,
                    facts = 3,
                    skills = 1,
                    accessibilityEnabled = true,
                    activeTab = "capabilities",
                    onSelectTab = {},
                    onOpenRunningApps = {},
                    onOpenSettings = {},
                    onOpenBrowser = {},
                    onOpenRuns = {},
                    onOpenMemory = {},
                    onOpenSkills = {},
                    accountLabel = "Signed in",
                    onOpenAccount = {},
                )
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/capabilities.png")
    }
}
