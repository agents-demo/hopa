package com.hopa.app.feature.power

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaBottomBar
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.core.contracts.RunRecord

/** The Power profile landing: a command bar, quick commands and recent actions. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PowerHomeScreen(
    recent: List<RunRecord>,
    active: String,
    onSelectTab: (String) -> Unit,
    onRun: (String) -> Unit,
) {
    var command by remember { mutableStateOf("") }
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                Text(
                    "Power",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
            }
        },
        bottomBar = {
            Column(modifier = Modifier.navigationBarsPadding()) {
                HopaBottomBar(active = active, onSelect = onSelectTab)
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
            Text(
                "COMMAND",
                fontSize = 10.sp,
                color = HopaColor.TextHint,
                letterSpacing = 0.6.sp,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = command,
                    onValueChange = { command = it },
                    placeholder = { Text("What should HOPA do?") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = {
                        val goal = command.trim()
                        if (goal.isNotEmpty()) {
                            command = ""
                            onRun(goal)
                        }
                    },
                    modifier = Modifier.padding(start = 8.dp),
                ) { Text("Run") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (prefix in listOf("/batch", "/replay", "/logs")) {
                    Text(
                        prefix,
                        fontSize = 12.sp,
                        color = HopaColor.Primary,
                        modifier = Modifier
                            .background(HopaColor.PrimarySoft, RoundedCornerShape(9.dp))
                            .clickable { command = if (command.isBlank()) "$prefix " else command }
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }

            Text(
                "RECENT",
                fontSize = 10.sp,
                color = HopaColor.TextHint,
                letterSpacing = 0.6.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
            if (recent.isEmpty()) {
                Text(
                    "No actions yet. Send a command above.",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(HopaColor.Surface, RoundedCornerShape(12.dp)),
                ) {
                    recent.take(5).forEach { record ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                actionLabel(record.action.kind),
                                fontSize = 13.sp,
                                color = HopaColor.TextPrimary,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                if (record.executed) "done" else "refused",
                                fontSize = 10.sp,
                                color = if (record.executed) {
                                    HopaColor.Success
                                } else {
                                    HopaColor.Danger
                                },
                            )
                        }
                    }
                }
            }
            Text(
                "Commands go straight to Chat. /batch, /replay and /logs are hints " +
                    "HOPA understands in the message.",
                fontSize = 11.sp,
                color = HopaColor.TextHint,
            )
        }
    }
}

private fun actionLabel(kind: String): String = when {
    kind == "ui.launch" -> "Opened an app"
    kind == "ui.tap" || kind == "ui.doubleTap" || kind == "ui.longPress" -> "Tapped the screen"
    kind == "ui.type" -> "Typed on the phone"
    kind == "ui.swipe" || kind == "ui.scroll" -> "Scrolled the screen"
    kind == "web.navigate" -> "Opened a page"
    kind == "web.read" -> "Read a page"
    kind.startsWith("system.") -> "System action"
    kind.startsWith("payment.") -> "Payment check"
    else -> kind
}
