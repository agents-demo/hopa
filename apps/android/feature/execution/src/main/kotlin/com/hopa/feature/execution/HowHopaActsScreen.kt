package com.hopa.feature.execution

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.PriorityHigh
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.feature.settings.BackgroundSetupDialog
import com.hopa.feature.settings.ModelOption
import com.hopa.feature.settings.SettingsUiState
import com.hopa.feature.settings.formatBytes
import com.hopa.ui.component.HopaPageHeader
import com.hopa.ui.settings.SettingsSegment
import com.hopa.ui.theme.HopaColor

/**
 * Two questions, in order: who sends the taps, and — on this phone — whether
 * the app opens out of sight or on the screen the person is watching. The apps
 * always stay on this phone; the computer is only another driver for this
 * phone's visible screen.
 */
@Composable
fun HowHopaActsScreen(
    state: SettingsUiState,
    pairingStatus: String?,
    onBack: () -> Unit,
    onScreenPath: (String) -> Unit,
    onStartBackgroundHelper: () -> Unit,
    onTestBridge: (String, String) -> Unit,
    onPairWireless: (String, String) -> Unit,
    onPairWirelessFromScreen: () -> Unit,
    onPairWirelessWaiting: () -> Unit,
    onOpenScreenAccess: () -> Unit,
    onOpenComputer: () -> Unit,
    onOpenSetup: () -> Unit,
    onOpenDecisions: () -> Unit,
    onStepSource: (String) -> Unit,
    onProvider: (String) -> Unit,
    onLocalModel: (String) -> Unit,
    onOpenAnswers: () -> Unit,
) {
    var setup by rememberSaveable { mutableStateOf(false) }
    val mode = ActMode.of(state)
    val bridgeReady = state.settings.bridgeUrl.isNotBlank() && state.bridgeKey.isNotBlank()

    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = { HopaPageHeader(title = "How HOPA acts", onBack = onBack) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("Who taps")
                ChoiceRow(
                    options = listOf(
                        ActChoice(false, "This phone", "taps here"),
                        ActChoice(true, "My computer", "HOPA bridge"),
                    ),
                    selected = mode.onComputer,
                    onPick = { computer ->
                        when {
                            computer -> onScreenPath("bridge")
                            mode.onComputer -> onScreenPath("auto")
                            else -> Unit
                        }
                    },
                )
                Text(
                    if (mode.onComputer) {
                        "The HOPA bridge on your computer sends the taps to this phone."
                    } else {
                        "HOPA taps on this phone. Apps stay here."
                    },
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                    minLines = 2,
                    maxLines = 2,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("On this phone")
                ChoiceRow(
                    options = listOf(
                        ActChoice(true, "Hidden screen", "out of sight"),
                        ActChoice(false, "Your screen", "you watch"),
                    ),
                    selected = if (mode.onComputer) null else mode.hidden,
                    onPick = { hidden ->
                        when {
                            hidden && !mode.hidden -> onScreenPath("auto")
                            !hidden -> onScreenPath("onscreen")
                            else -> Unit
                        }
                    },
                )
                Text(
                    if (mode.onComputer) {
                        "Pick a phone screen to switch back to This phone."
                    } else {
                        "Apps stay on this phone, hidden or visible."
                    },
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                    minLines = 2,
                    maxLines = 2,
                )
            }

            when {
                mode.onComputer -> ComputerStatus(
                    mode = mode,
                    busy = state.busy,
                    bridgeStatus = state.bridgeStatus,
                    onTest = { onTestBridge(state.settings.bridgeUrl, "") },
                    onSetup = onOpenComputer,
                    onEnable = { onScreenPath("bridge") },
                )

                mode.hidden -> HiddenStatus(
                    mode = mode,
                    bridgeReady = bridgeReady,
                    bridgeStatus = state.bridgeStatus,
                    onStart = onStartBackgroundHelper,
                    onSetup = { setup = true },
                    onScreenAccess = onOpenScreenAccess,
                    onOpenSetup = onOpenSetup,
                    onFallback = { on -> onScreenPath(if (on) "auto" else "background") },
                )

                else -> ScreenStatus(mode = mode, onScreenAccess = onOpenScreenAccess)
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("Model")
                SettingsSegment(
                    options = listOf(
                        "stub" to "Demo",
                        "server" to "Server",
                        "on-device" to "On-device",
                    ),
                    selected = when (state.settings.provider) {
                        "stub" -> "stub"
                        "on-device" -> "on-device"
                        else -> "server"
                    },
                    onSelect = onProvider,
                )
                if (state.settings.provider == "on-device") {
                    if (state.installedModels.isEmpty()) {
                        Text(
                            "No model on this phone yet. Download one in Answers.",
                            fontSize = 12.sp,
                            color = HopaColor.TextHint,
                        )
                    } else {
                        val active = state.settings.activeModelId.ifBlank {
                            state.installedModels.first().id
                        }
                        state.installedModels.forEach { model ->
                            ModelRow(
                                model = model,
                                selected = model.id == active,
                                onClick = { onLocalModel(model.id) },
                            )
                        }
                    }
                }
                Text(
                    modelNote(state.settings.provider, state.settings.model),
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
                if (state.settings.provider != "stub") {
                    TextButton(
                        onClick = onOpenAnswers,
                        contentPadding = PaddingValues(0.dp),
                    ) {
                        Text("Keys, endpoint and downloads", fontSize = 12.sp)
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("Who chooses")
                DecisionsCard(
                    mode = state.settings.decisionMode,
                    active = state.decisionActive,
                    onClick = onOpenDecisions,
                )
                Text(
                    "Rules answer a read in milliseconds; a change still asks you, and a payment always does.",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SectionLabel("Steps")
                SettingsSegment(
                    options = listOf(
                        "auto" to "Auto",
                        "model" to "Model",
                        "graph" to "Graph",
                    ),
                    selected = state.settings.stepSource,
                    onSelect = onStepSource,
                )
                Text(
                    stepSourceNote(state.settings.stepSource),
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
                if (state.settings.stepSource != "model" && state.graphPaths.isNotEmpty()) {
                    Text(
                        "Known paths",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = HopaColor.TextHint,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                    state.graphPaths.forEach { line ->
                        Text(line, fontSize = 11.sp, color = HopaColor.TextSecondary)
                    }
                }
            }

            if (mode.hidden) {
                pairingStatus?.let { message ->
                    Text(
                        message,
                        fontSize = 12.sp,
                        color = if (message.startsWith("Wireless shell") ||
                            message.startsWith("Paired")
                        ) {
                            HopaColor.Success
                        } else {
                            HopaColor.Warning
                        },
                    )
                }
            }
        }
    }

    if (setup) {
        BackgroundSetupDialog(
            busy = state.busy,
            onDismiss = { setup = false },
            onConnect = { address, code ->
                onPairWireless(address, code)
                setup = false
            },
            onPairAutomatically = {
                setup = false
                onPairWirelessFromScreen()
            },
            onWaitForDialog = {
                setup = false
                onPairWirelessWaiting()
            },
        )
    }
}

@Composable
private fun DecisionsCard(mode: String, active: Map<String, String>, onClick: () -> Unit) {
    val title = when (mode) {
        "auto" -> "Automatic"
        "rules" -> "Rules"
        "laix" -> "LAIX"
        else -> "The model"
    }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        color = HopaColor.Surface,
        shape = RoundedCornerShape(16.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = HopaColor.TextPrimary)
                Text(
                    "Reads: ${decisionLabel(active["read"])}  ·  Changes: ${decisionLabel(active["change"])}",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
            }
            Text("Change", fontSize = 13.sp, color = HopaColor.Primary)
        }
    }
}

private fun decisionLabel(id: String?): String = when (id) {
    null, "", "model" -> "Model"
    "rules" -> "Rules"
    "laix" -> "LAIX"
    else -> id
}

private fun stepSourceNote(source: String): String = when (source) {
    "model" -> "The model writes every step, as before."
    "graph" -> "Graph only: Settings, Clock and Camera; other goals are refused."
    else -> "A graph first for Settings, Clock and Camera; the model for everything else."
}

private fun modelNote(provider: String, cloudModel: String): String = when (provider) {
    "on-device" -> "Answers stay on this phone."
    "stub" -> "Demo answers; no model is called."
    else -> "Cloud or your own server \u00B7 " + cloudModel.ifBlank { "no model set" }
}

/** One installed model, with the check that says which one answers. */
@Composable
private fun ModelRow(model: ModelOption, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (selected) HopaColor.PrimarySoft else HopaColor.Surface,
                RoundedCornerShape(12.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            model.label,
            fontSize = 14.sp,
            color = HopaColor.TextPrimary,
            modifier = Modifier.weight(1f),
        )
        Text(formatBytes(model.bytes), fontSize = 11.sp, color = HopaColor.TextHint)
        if (selected) {
            Spacer(modifier = Modifier.width(8.dp))
            Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = "Selected",
                tint = HopaColor.Primary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun HiddenStatus(
    mode: ActMode,
    bridgeReady: Boolean,
    bridgeStatus: String?,
    onStart: () -> Unit,
    onSetup: () -> Unit,
    onScreenAccess: () -> Unit,
    onOpenSetup: () -> Unit,
    onFallback: (Boolean) -> Unit,
) {
    val accessOff = !mode.phoneAccess
    val helperOff = !mode.hiddenHelper
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        when {
            mode.hiddenReady -> StatusCard(
                ok = true,
                title = "Hidden screen is ready.",
                body = "HOPA works without taking over your screen.",
            ) {
                FallbackChoice(useScreen = mode.fallback, onChange = onFallback)
                TextButton(onClick = onOpenSetup) {
                    Text("Hidden screen settings", fontSize = 12.sp)
                }
            }

            accessOff && helperOff -> StatusCard(
                ok = false,
                title = "Hidden screen needs setup.",
                body = "Turn on screen access, then start the hidden screen.",
                action = "Finish setup",
                onAction = onOpenSetup,
            ) {
                FallbackChoice(useScreen = mode.fallback, onChange = onFallback)
            }

            accessOff -> StatusCard(
                ok = false,
                title = if (mode.pausedByYou) {
                    "Screen access is paused by you."
                } else {
                    "Screen access is off."
                },
                body = "The hidden screen needs it to read the app.",
                action = if (mode.pausedByYou) "Resume screen access" else "Turn on screen access",
                onAction = onScreenAccess,
            ) {
                FallbackChoice(useScreen = mode.fallback, onChange = onFallback)
            }

            else -> StatusCard(
                ok = false,
                title = "Hidden screen isn't running.",
                body = if (mode.fallback && mode.screenReady) {
                    "HOPA will use your screen until it starts."
                } else {
                    "Start it to work out of sight."
                },
                action = if (bridgeReady) "Start the hidden screen" else "Set up the hidden screen",
                onAction = if (bridgeReady) onStart else onSetup,
            ) {
                FallbackChoice(useScreen = mode.fallback, onChange = onFallback)
            }
        }
        bridgeStatus?.let { StatusMessage(it) }
    }
}

@Composable
private fun ScreenStatus(mode: ActMode, onScreenAccess: () -> Unit) {
    when {
        mode.screenReady -> StatusCard(
            ok = true,
            title = "Screen access is on.",
            body = "You watch every tap.",
        ) {
            TextButton(onClick = onScreenAccess) {
                Text("Screen access settings", fontSize = 12.sp)
            }
        }

        mode.pausedByYou -> StatusCard(
            ok = false,
            title = "Screen access is paused by you.",
            body = "Turn it back on to use this screen.",
            action = "Resume screen access",
            onAction = onScreenAccess,
        )

        else -> StatusCard(
            ok = false,
            title = "Screen access is off.",
            body = "HOPA needs it to see and tap on this screen.",
            action = "Turn on screen access",
            onAction = onScreenAccess,
        )
    }
}

@Composable
private fun ComputerStatus(
    mode: ActMode,
    busy: Boolean,
    bridgeStatus: String?,
    onTest: () -> Unit,
    onSetup: () -> Unit,
    onEnable: () -> Unit,
) {
    StatusCard(
        ok = mode.computerReady,
        title = when {
            mode.computerReady -> "HOPA bridge is ready."
            mode.computerPaired -> "HOPA bridge is switched off."
            else -> "HOPA bridge isn't set up."
        },
        body = when {
            mode.computerReady -> "It sends the taps to this phone; apps still open here."
            mode.computerPaired -> "Turn it on to send the taps."
            else -> "Pair it once to let it send the taps."
        },
        action = when {
            mode.computerReady -> null
            mode.computerPaired -> "Turn the bridge on"
            else -> "Set up the bridge"
        },
        actionEnabled = !busy,
        onAction = if (mode.computerPaired && !mode.computerReady) onEnable else onSetup,
    ) {
        if (mode.computerReady) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(onClick = onTest, enabled = !busy) {
                    Text("Test bridge", fontSize = 12.sp)
                }
                TextButton(onClick = onSetup) {
                    Text("Bridge settings", fontSize = 12.sp)
                }
            }
        }
    }
    bridgeStatus?.let { StatusMessage(it) }
}

@Composable
private fun StatusMessage(message: String) {
    Text(
        message,
        fontSize = 12.sp,
        color = if (message.startsWith("Bridge ok") ||
            message.startsWith("Bridge paired") ||
            message.contains("is ready", true)
        ) {
            HopaColor.Success
        } else {
            HopaColor.Warning
        },
    )
}

@Composable
private fun StatusCard(
    ok: Boolean,
    title: String,
    body: String,
    action: String? = null,
    actionEnabled: Boolean = true,
    onAction: () -> Unit = {},
    content: @Composable ColumnScope.() -> Unit = {},
) {
    val accent = if (ok) HopaColor.Success else HopaColor.Warning
    Surface(
        color = accent.copy(alpha = 0.07f),
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.dp, accent.copy(alpha = 0.18f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
            ) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .background(accent.copy(alpha = 0.14f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (ok) Icons.Outlined.Check else Icons.Outlined.PriorityHigh,
                        contentDescription = null,
                        tint = accent,
                        modifier = Modifier.size(18.dp),
                    )
                }
                Spacer(Modifier.width(10.dp))
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text(
                        title,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = HopaColor.TextPrimary,
                    )
                    Text(
                        body,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                        color = HopaColor.TextSecondary,
                    )
                }
            }
            if (action != null) {
                Button(
                    onClick = onAction,
                    enabled = actionEnabled,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(46.dp),
                ) {
                    Text(action, fontSize = 14.sp)
                }
            }
            content()
        }
    }
}

@Composable
private fun FallbackChoice(useScreen: Boolean, onChange: (Boolean) -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            "If the hidden screen can't start",
            fontSize = 11.sp,
            color = HopaColor.TextHint,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            FallbackPill(
                text = "Use your screen",
                selected = useScreen,
                modifier = Modifier.weight(1f),
                onClick = { onChange(true) },
            )
            FallbackPill(
                text = "Stop and tell me",
                selected = !useScreen,
                modifier = Modifier.weight(1f),
                onClick = { onChange(false) },
            )
        }
    }
}

@Composable
private fun FallbackPill(
    text: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        color = if (selected) HopaColor.PrimarySoft else HopaColor.Surface,
        shape = RoundedCornerShape(10.dp),
        border = BorderStroke(1.dp, if (selected) HopaColor.Primary else HopaColor.Divider),
        modifier = modifier
            .height(44.dp)
            .selectable(
                selected = selected,
                role = Role.RadioButton,
                onClick = onClick,
            ),
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text,
                fontSize = 12.sp,
                fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
                color = if (selected) HopaColor.Primary else HopaColor.TextSecondary,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.8.sp,
        color = HopaColor.TextHint,
    )
}

private data class ActChoice(
    val value: Boolean,
    val title: String,
    val hint: String,
)

@Composable
private fun ChoiceRow(
    options: List<ActChoice>,
    selected: Boolean?,
    onPick: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { option ->
            val active = option.value == selected
            Surface(
                color = if (active) HopaColor.PrimarySoft else HopaColor.Surface,
                shape = RoundedCornerShape(14.dp),
                border = BorderStroke(1.dp, if (active) HopaColor.Primary else HopaColor.Divider),
                modifier = Modifier
                    .weight(1f)
                    .selectable(
                        selected = active,
                        role = Role.RadioButton,
                        onClick = { onPick(option.value) },
                    ),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        option.title,
                        fontSize = 14.sp,
                        fontWeight = if (active) FontWeight.Medium else FontWeight.Normal,
                        color = if (active) HopaColor.Primary else HopaColor.TextSecondary,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                    )
                    Text(
                        option.hint,
                        fontSize = 10.sp,
                        color = if (active) {
                            HopaColor.Primary.copy(alpha = 0.78f)
                        } else {
                            HopaColor.TextHint
                        },
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}
