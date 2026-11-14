package com.hopa.app.feature.device

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
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceScreen(
    state: DeviceUiState,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOpenBridgeSettings: () -> Unit,
    onOpenAccessibility: () -> Unit,
) {
    val ready = state.bridgeOk == true || state.accessibilityLive
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
                    "Device control",
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
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(14.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        if (ready) "HOPA can act" else "HOPA cannot act yet",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (ready) HopaColor.Success else HopaColor.Warning,
                    )
                    Text(
                        if (ready) {
                            "One path is ready. The PC bridge is preferred."
                        } else {
                            "Connect the bridge or grant accessibility. Until then every " +
                                "device action is refused with an honest reason."
                        },
                        fontSize = 12.sp,
                        color = HopaColor.TextHint,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }

            Text(
                "PC BRIDGE",
                fontSize = 10.sp,
                color = HopaColor.TextHint,
                letterSpacing = 0.6.sp,
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        when {
                            !state.bridgeConfigured -> "Not configured"
                            state.bridgeOk == true -> "Connected"
                            state.bridgeOk == false -> "Configured, unreachable"
                            else -> "Configured, not checked"
                        },
                        fontSize = 14.sp,
                        color = HopaColor.TextPrimary,
                    )
                    Text(
                        state.bridgeUrl.ifBlank { "No address" },
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                    )
                    state.bridgeError?.let { error ->
                        Text(error, fontSize = 11.sp, color = HopaColor.Danger)
                    }
                }
                OutlinedButton(onClick = onRetry, enabled = !state.checking) {
                    Text(if (state.checking) "Checking\u2026" else "Retry")
                }
            }
            Button(onClick = onOpenBridgeSettings, modifier = Modifier.fillMaxWidth()) {
                Text("Bridge settings")
            }

            Text(
                "ON-DEVICE",
                fontSize = 10.sp,
                color = HopaColor.TextHint,
                letterSpacing = 0.6.sp,
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        when {
                            !state.accessibilityEnabled -> "Service off"
                            state.accessibilityLive -> "Enabled and connected"
                            else -> "Enabled, not connected yet"
                        },
                        fontSize = 14.sp,
                        color = HopaColor.TextPrimary,
                    )
                    Text(
                        "Accessibility acts locally when no PC is connected.",
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                    )
                }
            }
            Button(onClick = onOpenAccessibility, modifier = Modifier.fillMaxWidth()) {
                Text("Phone access")
            }
        }
    }
}
