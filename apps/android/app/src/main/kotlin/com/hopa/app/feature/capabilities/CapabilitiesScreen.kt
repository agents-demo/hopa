package com.hopa.app.feature.capabilities

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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaBottomBar
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.capabilities.llm.ProviderState

/** Capabilities: what HOPA can use on this phone and what powers it. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CapabilitiesScreen(
    provider: ProviderState,
    endpoint: String,
    records: Int,
    apps: Int,
    facts: Int = 0,
    skills: Int = 0,
    accessibilityEnabled: Boolean,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenDevice: () -> Unit,
    onOpenBrowser: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenMemory: () -> Unit,
    onUnavailable: (String) -> Unit,
) {
    val ready = accessibilityEnabled
    val control = if (accessibilityEnabled) "On-device" else "Not set up"
    val model = if (provider == ProviderState.NO_MODEL) "No model" else provider.label()
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                Text(
                    text = "Capabilities",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = "Settings",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.Primary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .clickable(onClick = onOpenSettings)
                        .background(HopaColor.PrimarySoft, RoundedCornerShape(20.dp))
                        .width(88.dp)
                        .height(40.dp)
                        .padding(top = 10.dp),
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
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(14.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(14.dp))
                    .clickable(onClick = onOpenDevice)
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
                        text = if (ready) "Ready on this phone" else "Finish setup",
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
                            text = "$model \u00b7 $control",
                            fontSize = 11.sp,
                            color = HopaColor.TextSecondary,
                        )
                    }
                }
            }

            SectionLabel("WHAT HOPA CAN USE")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Launchpad",
                    subtitle = "Apps and sites to open",
                    onClick = onOpenLaunchpad,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "Browser",
                    subtitle = "Read, click and type",
                    onClick = onOpenBrowser,
                    modifier = Modifier.weight(1f),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Memory",
                    subtitle = if (facts == 1) "1 fact" else "$facts facts",
                    onClick = onOpenMemory,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "Runs",
                    subtitle = actionCountLabel(records),
                    onClick = onOpenRuns,
                    modifier = Modifier.weight(1f),
                )
            }

            SectionLabel("TOOLS")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Usage",
                    subtitle = "$records recorded",
                    onClick = onOpenUsage,
                    modifier = Modifier.weight(1f),
                )
                Tile(
                    title = "MCP servers",
                    subtitle = "Phone and PC tools",
                    onClick = { onUnavailable("MCP servers") },
                    modifier = Modifier.weight(1f),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile(
                    title = "Skills",
                    subtitle = if (skills == 1) "1 trigger" else "$skills triggers",
                    onClick = onOpenMemory,
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

private fun ProviderState.label(): String = when (this) {
    ProviderState.CLOUD -> "Cloud model"
    ProviderState.LAN -> "LAN model"
    ProviderState.DEMO -> "Demo model (no key)"
    ProviderState.NO_MODEL -> "No model"
}
