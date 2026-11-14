package com.hopa.app.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SelfCheckScreen(
    state: SelfCheckUiState,
    onBack: () -> Unit,
    onRetry: () -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = HopaColor.TextPrimary,
                    )
                }
                Text(
                    "Self-check",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(14.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
                    .padding(14.dp),
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Model", fontSize = 13.sp, color = HopaColor.TextHint)
                    Text(state.model, fontSize = 15.sp, color = HopaColor.TextPrimary)
                    Text(state.provider, fontSize = 11.sp, color = HopaColor.TextHint)
                }
            }
            CheckRow(
                title = "PC bridge",
                value = when {
                    state.bridgeUrl.isBlank() -> "Not configured"
                    state.bridgeOk == true -> "Connected"
                    state.bridgeOk == false -> "Unreachable"
                    else -> "Not checked"
                },
                ok = state.bridgeOk == true,
                detail = state.bridgeUrl.ifBlank { " " },
            )
            CheckRow(
                title = "On-device accessibility",
                value = when {
                    state.accessibilityEnabled && state.accessibilityLive -> "Enabled and connected"
                    state.accessibilityEnabled -> "Enabled, not connected"
                    else -> "Off"
                },
                ok = state.accessibilityLive,
                detail = " ",
            )
            CheckRow(
                title = "Data",
                value = "${state.sessions} chats, ${state.records} records",
                ok = true,
                detail = "${state.facts} facts, ${state.skills} skills",
            )
            Button(
                onClick = onRetry,
                enabled = !state.checking,
                modifier = Modifier.padding(top = 8.dp),
            ) {
                Text(if (state.checking) "Checking\u2026" else "Run self-check")
            }
        }
    }
}

@Composable
private fun CheckRow(title: String, value: String, ok: Boolean, detail: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, color = HopaColor.TextHint)
            Text(
                value,
                fontSize = 15.sp,
                color = if (ok) HopaColor.Success else HopaColor.Warning,
            )
            Text(detail, fontSize = 11.sp, color = HopaColor.TextHint)
        }
    }
}
