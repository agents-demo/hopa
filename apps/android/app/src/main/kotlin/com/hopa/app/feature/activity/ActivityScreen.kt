package com.hopa.app.feature.activity

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaBottomBar
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.core.contracts.RunRecord
import java.time.Instant

/** Activity: what HOPA is doing, what it did and what is scheduled. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivityScreen(
    state: ActivityUiState,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onShare: () -> Unit,
    onUnavailable: (String) -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                Text(
                    text = "Activity",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
            }
        },
        bottomBar = {
            Column(modifier = Modifier.navigationBarsPadding()) {
                HopaBottomBar(active = activeTab, onSelect = onSelectTab)
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            StatusCard(state)

            if (state.lastGoal.isNotEmpty()) {
                SectionLabel("LAST RUN")
                LastRunCard(state)
            }

            SectionLabel("WEEK")
            WeekCard(state = state, onShare = onShare)

            val recent = state.records.takeLast(3).reversed()
            if (recent.isNotEmpty()) {
                SectionLabel("RECENT ACTIONS")
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                        .padding(horizontal = 12.dp),
                ) {
                    recent.forEach { record ->
                        RecentActionRow(record)
                    }
                }
            }

            SectionLabel("RECENT")
            NavCard("Runs and batches", "Every action, approval and duration", onOpenRuns)
            NavCard("Usage", "Tokens and time spent", onOpenUsage)

            SectionLabel("SCHEDULED")
            NavCard("Plans", "Goals that run while HOPA is open") { onUnavailable("Plans") }
        }
    }
}

@Composable
private fun StatusCard(state: ActivityUiState) {
    val lastRun = state.records.lastOrNull()?.timestamp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        HopaMascot(
            sizeDp = 34.dp,
            state = if (state.busy) "acting" else "idle",
            interactive = false,
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(9.dp)
                        .background(
                            color = if (state.busy) HopaColor.Warning else HopaColor.Success,
                            shape = CircleShape,
                        ),
                )
                Text(
                    text = if (state.busy) "Working on something" else "Ready",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
            }
            Text(
                text = if (lastRun == null) "No run yet." else "Last run: ${ago(lastRun)}",
                fontSize = 11.sp,
                color = HopaColor.TextHint,
            )
            Text(
                text = actionCountLabel(state.records.size),
                fontSize = 11.sp,
                color = HopaColor.TextHint,
            )
        }
    }
}

@Composable
private fun LastRunCard(state: ActivityUiState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = state.lastGoal,
            fontSize = 13.sp,
            color = HopaColor.TextPrimary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (state.lastSteps.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                state.lastSteps.forEach { kind ->
                    Text(
                        text = actionLabel(kind),
                        fontSize = 10.5.sp,
                        color = HopaColor.TextSecondary,
                        maxLines = 1,
                        modifier = Modifier
                            .background(HopaColor.SurfaceAlt, RoundedCornerShape(8.dp))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun WeekCard(state: ActivityUiState, onShare: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
            .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text("Week in review", fontSize = 14.sp, color = HopaColor.TextPrimary)
            Text(
                "${state.weekActions} actions \u00b7 ${state.weekDone} done \u00b7 ${state.weekApps} apps",
                fontSize = 10.5.sp,
                color = HopaColor.TextHint,
            )
        }
        Text(
            text = "Share",
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = HopaColor.Primary,
            modifier = Modifier
                .clickable(onClick = onShare)
                .background(HopaColor.PrimarySoft, RoundedCornerShape(9.dp))
                .padding(horizontal = 10.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun RecentActionRow(record: RunRecord) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(38.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .background(statusColor(record), CircleShape),
        )
        Text(
            text = actionLabel(record.action.kind),
            fontSize = 13.sp,
            color = HopaColor.TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = ago(record.timestamp),
            fontSize = 10.sp,
            color = HopaColor.TextHint,
        )
    }
}

@Composable
private fun SectionLabel(label: String) {
    Text(
        text = label,
        fontSize = 10.sp,
        color = HopaColor.TextHint,
        letterSpacing = 0.6.sp,
        modifier = Modifier.padding(top = 6.dp),
    )
}

@Composable
private fun NavCard(title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, color = HopaColor.TextPrimary)
            Text(subtitle, fontSize = 11.sp, color = HopaColor.TextHint)
        }
        Text("\u203a", fontSize = 17.sp, color = HopaColor.TextHint)
    }
}

private fun statusColor(record: RunRecord) = when {
    record.executed -> HopaColor.Success
    record.error != null -> HopaColor.Danger
    else -> HopaColor.Warning
}

private fun actionCountLabel(count: Int): String =
    "$count ${if (count == 1) "action" else "actions"} recorded"

private fun actionLabel(kind: String): String = when {
    kind == "web.navigate" -> "Opened a page"
    kind == "web.read" -> "Read a page"
    kind == "web.click" -> "Clicked on a page"
    kind == "web.type" -> "Typed on a page"
    kind == "ui.launch" -> "Opened an app"
    kind == "ui.tap" || kind == "ui.doubleTap" || kind == "ui.longPress" -> "Tapped the screen"
    kind == "ui.type" -> "Typed on the phone"
    kind == "ui.scroll" -> "Scrolled the screen"
    kind == "ui.back" -> "Went back"
    kind == "ui.home" -> "Went home"
    kind.startsWith("sandbox.") -> "Ran a script"
    kind.startsWith("system.") -> "System action"
    else -> kind
}

private fun ago(timestamp: String?): String {
    if (timestamp.isNullOrBlank()) {
        return "now"
    }
    val millis = try {
        Instant.parse(timestamp).toEpochMilli()
    } catch (error: Exception) {
        return "now"
    }
    val diff = System.currentTimeMillis() - millis
    return when {
        diff < 60_000 -> "now"
        diff < 3_600_000 -> "${diff / 60_000}m"
        diff < 86_400_000 -> "${diff / 3_600_000}h"
        else -> "${diff / 86_400_000}d"
    }
}
