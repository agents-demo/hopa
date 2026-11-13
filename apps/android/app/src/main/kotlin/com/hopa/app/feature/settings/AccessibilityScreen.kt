package com.hopa.app.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor

/** The disclosure a person reads before granting the accessibility service. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccessibilityScreen(
    allowed: Boolean,
    serviceEnabled: Boolean,
    connected: Boolean,
    onToggle: (Boolean) -> Unit,
    onOpenSettings: () -> Unit,
    onBack: () -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            TopAppBar(
                title = { Text("Phone access") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Surface(
                color = HopaColor.Surface,
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "What HOPA reads",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = HopaColor.TextPrimary,
                    )
                    Text(
                        "HOPA reads the visible screen text, button labels and their " +
                            "positions so it can act for you. It does not read passwords: " +
                            "password fields are dropped, and emails, phone numbers, cards " +
                            "and one-time codes are replaced before anything leaves the " +
                            "phone. Screenshots are taken only during a run and never more " +
                            "than once a second, and a screen that hides itself stays hidden.",
                        fontSize = 13.sp,
                        color = HopaColor.TextSecondary,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Allow HOPA to act on this phone")
                    Text(
                        "Off means every device action is refused, even if Android still " +
                            "has the service enabled.",
                        fontSize = 12.sp,
                        color = HopaColor.TextHint,
                    )
                }
                Switch(checked = allowed, onCheckedChange = onToggle)
            }
            Surface(
                color = HopaColor.SurfaceAlt,
                shape = MaterialTheme.shapes.small,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text(
                        if (serviceEnabled) "Android service: enabled" else "Android service: off",
                        fontSize = 13.sp,
                        color = if (serviceEnabled) HopaColor.Success else HopaColor.Warning,
                    )
                    Text(
                        if (connected) "Connection: live" else "Connection: not connected yet",
                        fontSize = 13.sp,
                        color = if (connected) HopaColor.Success else HopaColor.TextHint,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            Button(onClick = onOpenSettings) {
                Text("Open Android accessibility settings")
            }
            Text(
                "The PC bridge is the preferred path. Accessibility is the fallback " +
                    "that keeps working when no PC is connected.",
                fontSize = 12.sp,
                color = HopaColor.TextHint,
            )
        }
    }
}
