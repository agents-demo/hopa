package com.hopa.feature.capabilities

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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.ui.component.HopaBottomBar
import com.hopa.ui.component.HopaMascot
import com.hopa.ui.component.HopaPageHeader
import com.hopa.ui.theme.HopaColor

/** Capabilities: what HOPA can use on this phone and what powers it. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CapabilitiesScreen(
    records: Int,
    facts: Int = 0,
    skills: Int = 0,
    accessibilityEnabled: Boolean,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenRunningApps: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenBrowser: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenMemory: () -> Unit,
    onOpenSkills: () -> Unit,
    accountTitle: String = "Sign in",
    accountHint: String = "Connect this phone with your computer",
    onOpenAccount: () -> Unit = {},
) {
    val ready = accessibilityEnabled
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaPageHeader(title = "Capabilities")
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
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(14.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
                    .clickable(onClick = onOpenRunningApps)
                    .padding(14.dp),
                verticalAlignment = Alignment.Top,
            ) {
                HopaMascot(sizeDp = 46.dp, state = "idle", interactive = false)
                Spacer(modifier = Modifier.width(12.dp))
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = "Act",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Medium,
                        color = HopaColor.TextPrimary,
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(
                                    color = if (ready) HopaColor.Success else HopaColor.Warning,
                                    shape = CircleShape,
                                ),
                        )
                        Text(
                            text = if (ready) {
                                "Screen access on"
                            } else {
                                "Needs screen access"
                            },
                            fontSize = 11.sp,
                            color = HopaColor.TextSecondary,
                        )
                    }
                    Text(
                        text = "How HOPA acts, the apps and sites it can open, " +
                            "and the setup behind them.",
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                    )
                }
            }

            SectionLabel("WHAT HOPA CAN USE")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Browser",
                    subtitle = "Read, click and type",
                    onClick = onOpenBrowser,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "Memory",
                    subtitle = if (facts == 1) "1 fact" else "$facts facts",
                    onClick = onOpenMemory,
                    modifier = Modifier.weight(1f),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Runs",
                    subtitle = actionCountLabel(records),
                    onClick = onOpenRuns,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "Skills",
                    subtitle = if (skills == 1) "1 trigger" else "$skills triggers",
                    onClick = onOpenSkills,
                    modifier = Modifier.weight(1f),
                )
            }

            SectionLabel("HOPA")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = accountTitle,
                    subtitle = accountHint,
                    onClick = onOpenAccount,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "Settings",
                    subtitle = "Keys, models and privacy",
                    onClick = onOpenSettings,
                    modifier = Modifier.weight(1f),
                )
            }
        }
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
private fun Tile(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .height(88.dp)
            .shadow(
                elevation = 3.dp,
                shape = RoundedCornerShape(16.dp),
                ambientColor = Color(0x091C1B18),
                spotColor = Color(0x091C1B18),
            )
            .background(HopaColor.Surface, RoundedCornerShape(16.dp))
            .border(1.dp, Color(0x0F1C1B18), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = title,
            fontSize = 15.5.sp,
            fontWeight = FontWeight.Medium,
            color = HopaColor.TextPrimary,
        )
        Text(
            text = subtitle,
            fontSize = 11.sp,
            color = HopaColor.TextHint,
            maxLines = 2,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

private fun actionCountLabel(count: Int): String =
    "$count ${if (count == 1) "action" else "actions"}"
