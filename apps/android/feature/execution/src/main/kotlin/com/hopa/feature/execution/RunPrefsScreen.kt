package com.hopa.feature.execution

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.feature.settings.SettingsUiState
import com.hopa.ui.component.HopaPageHeader
import com.hopa.ui.theme.HopaColor

/** How a run behaves, apart from where it runs. */
@Composable
fun RunPrefsScreen(
    state: SettingsUiState,
    onBack: () -> Unit,
    onPlanFirst: (Boolean) -> Unit,
    onVision: (Boolean) -> Unit,
    onReplaySkills: (Boolean) -> Unit,
    onCloudFallback: (Boolean) -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = { HopaPageHeader(title = "Run preferences", onBack = onBack) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 4.dp),
        ) {
            Surface(
                color = HopaColor.Surface,
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, HopaColor.Divider),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    SwitchRow(
                        "Plan first",
                        "Ask before the first tap",
                        state.settings.planFirst,
                        onPlanFirst,
                    )
                    RunPrefsLine()
                    SwitchRow(
                        "Look at the screen",
                        "Send a screenshot with the request",
                        state.settings.vision,
                        onVision,
                    )
                    RunPrefsLine()
                    SwitchRow(
                        "Repeat what worked",
                        "Skip the model next time",
                        state.settings.replaySkills,
                        onReplaySkills,
                    )
                    RunPrefsLine()
                    SwitchRow(
                        "Cloud fallback",
                        "If the on-device model is not sure, ask the API model. " +
                            "The screen and the goal leave the phone.",
                        state.settings.cloudFallback,
                        onCloudFallback,
                    )
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, color = HopaColor.TextPrimary)
            Text(subtitle, fontSize = 12.sp, color = HopaColor.TextHint)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun RunPrefsLine() {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(HopaColor.Divider),
    )
}
