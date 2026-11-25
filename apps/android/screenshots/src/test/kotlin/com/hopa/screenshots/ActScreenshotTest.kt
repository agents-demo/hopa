package com.hopa.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.hopa.feature.execution.HowHopaActsScreen
import com.hopa.feature.settings.SettingsUiState
import com.hopa.stores.AppSettings
import com.hopa.ui.theme.HopaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** How HOPA acts, including the Decisions entry that decides who acts. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-xxhdpi")
class ActScreenshotTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun onThisPhone() {
        compose.setContent {
            HopaTheme {
                HowHopaActsScreen(
                    state = SettingsUiState(
                        settings = AppSettings(
                            screenPath = "onscreen",
                            decisionMode = "auto",
                            provider = "on-device",
                            activeModelId = "qwen3-4b",
                        ),
                        decisionActive = mapOf(
                            "read" to "rules",
                            "change" to "model",
                            "dangerous" to "model",
                        ),
                        graphPaths = listOf(
                            "Settings: Wi-Fi, Bluetooth",
                            "Clock: Alarms, Timer",
                            "Camera: open",
                        ),
                        installedModels = listOf(
                            com.hopa.feature.settings.ModelOption(
                                id = "qwen3-4b",
                                label = "Qwen3 4B",
                                bytes = 2_497_280_256,
                            ),
                            com.hopa.feature.settings.ModelOption(
                                id = "gemma3-1b",
                                label = "Gemma 3 1B",
                                bytes = 806_058_240,
                            ),
                        ),
                    ),
                    pairingStatus = null,
                    onBack = {},
                    onScreenPath = {},
                    onStartBackgroundHelper = {},
                    onTestBridge = { _, _ -> },
                    onPairWireless = { _, _ -> },
                    onPairWirelessFromScreen = {},
                    onPairWirelessWaiting = {},
                    onOpenScreenAccess = {},
                    onOpenComputer = {},
                    onOpenSetup = {},
                    onOpenDecisions = {},
                    onStepSource = {},
                    onTreeRanker = {},
                    onProvider = {},
                    onLocalModel = {},
                    onOpenAnswers = {},
                )
            }
        }
        compose.onRoot().captureRoboImage("src/test/screenshots/how-hopa-acts.png")
    }
}
