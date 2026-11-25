package com.hopa.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.inference.local.ModelSpec
import com.hopa.ui.theme.HopaColor

/**
 * The on-device part of the Answers page.
 *
 * A card for the model this phone is offered, a quiet row per installed model
 * with removal behind a confirmation, and cards for what can be downloaded.
 * Nothing is red unless it is inside a confirmation: a delete is a deliberate
 * action, not a warning banner.
 */
@Composable
fun LocalModelSection(
    state: LocalModelUiState,
    onImport: () -> Unit,
    onDownload: (ModelSpec) -> Unit,
    onDelete: (String) -> Unit,
    onDeleteAll: () -> Unit,
    onUse: (String) -> Unit = {},
    onAcceptLicence: () -> Unit = {},
    onCancelLicence: () -> Unit = {},
) {
    var pendingDelete by remember { mutableStateOf<String?>(null) }
    var confirmDeleteAll by remember { mutableStateOf(false) }
    // A row opens its card in place, so every model can be compared without
    // making every card permanent.
    var openInstalled by remember { mutableStateOf<String?>(null) }
    var openAvailable by remember { mutableStateOf<String?>(null) }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "On this phone",
                style = MaterialTheme.typography.titleMedium,
                color = HopaColor.TextPrimary,
                modifier = Modifier.weight(1f),
            )
            Pill("${state.ramGb} GB RAM")
        }
        Text(
            "Answers stay on the device. Nothing is sent to a server.",
            style = MaterialTheme.typography.bodySmall,
            color = HopaColor.TextHint,
        )

        val recommended = state.recommended
        if (recommended == null) {
            SurfaceNote("No model fits the free space right now.")
        } else {
            val installed = state.installed.any { it.id == recommended.id }
            ModelCard(
                spec = recommended,
                state = state,
                installed = installed,
                active = recommended.id == state.activeId,
                onImport = onImport,
                onDownload = onDownload,
                onDelete = onDelete,
            )
        }

        if (state.installed.isNotEmpty()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Installed",
                    style = MaterialTheme.typography.titleSmall,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "${formatBytes(state.totalBytes)} of ${formatBytes(state.quotaBytes)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = HopaColor.TextHint,
                )
            }
            state.installed.forEach { model ->
                val spec = state.installedSpecs[model.id]
                val active = model.id == state.activeId
                InstalledRow(
                    title = spec?.name ?: model.id,
                    subtitle = when {
                        model.id in state.updates ->
                            "${formatBytes(model.bytes)}  ·  update available"
                        active -> "${formatBytes(model.bytes)}  ·  In use"
                        else -> "${formatBytes(model.bytes)}  ·  Installed"
                    },
                    spec = spec,
                    active = active,
                    expanded = openInstalled == model.id,
                    onToggle = {
                        openInstalled = if (openInstalled == model.id) null else model.id
                    },
                    onDelete = { pendingDelete = model.id },
                    onUse = { onUse(model.id) },
                    onUpdate = spec?.takeIf { model.id in state.updates }?.let { current ->
                        { onDownload(current) }
                    },
                )
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onClick = { confirmDeleteAll = true }) {
                    Text("Remove all models", color = HopaColor.TextSecondary)
                }
            }
        }

        val downloadable = state.installedSpecs.values
            .filter { spec -> spec.downloadable && state.installed.none { it.id == spec.id } }
            .sortedBy { spec -> spec.bytes }
        if (downloadable.isNotEmpty()) {
            Text(
                "Also available",
                style = MaterialTheme.typography.titleSmall,
                color = HopaColor.TextPrimary,
                modifier = Modifier.padding(top = 4.dp),
            )
            downloadable.forEach { spec ->
                DownloadRow(
                    spec = spec,
                    state = state,
                    expanded = openAvailable == spec.id,
                    onToggle = {
                        openAvailable = if (openAvailable == spec.id) null else spec.id
                    },
                    onDownload = onDownload,
                )
            }
        }

        state.notice?.let { Notice(it, HopaColor.Success) }
        state.error?.let { Notice(it, HopaColor.Danger) }
    }

    pendingDelete?.let { id ->
        val spec = state.installedSpecs[id]
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Remove ${spec?.name ?: id}?") },
            text = { Text("Frees ${formatBytes(state.installed.firstOrNull { it.id == id }?.bytes ?: 0)}. You can download it again.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        pendingDelete = null
                        onDelete(id)
                    },
                ) { Text("Remove", color = HopaColor.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Keep") }
            },
        )
    }

    state.licenceFor?.let { spec ->
        AlertDialog(
            onDismissRequest = onCancelLicence,
            title = { Text("Download ${spec.name}?") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Licence: ${spec.license}")
                    if (spec.licenseUrl.isNotBlank()) {
                        Text(
                            spec.licenseUrl,
                            style = MaterialTheme.typography.bodySmall,
                            color = HopaColor.Primary,
                        )
                    }
                    Text(
                        "Accepting is stored for this exact file. A new version asks again.",
                        style = MaterialTheme.typography.bodySmall,
                        color = HopaColor.TextHint,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = onAcceptLicence) { Text("Accept and download") }
            },
            dismissButton = {
                TextButton(onClick = onCancelLicence) { Text("Not now") }
            },
        )
    }

    if (confirmDeleteAll) {
        AlertDialog(
            onDismissRequest = { confirmDeleteAll = false },
            title = { Text("Remove all models?") },
            text = { Text("Frees ${formatBytes(state.totalBytes)}. Your chats and history stay.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmDeleteAll = false
                        onDeleteAll()
                    },
                ) { Text("Remove all", color = HopaColor.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDeleteAll = false }) { Text("Keep") }
            },
        )
    }
}

@Composable
private fun ModelCard(
    spec: ModelSpec,
    state: LocalModelUiState,
    installed: Boolean,
    active: Boolean,
    onImport: () -> Unit,
    onDownload: (ModelSpec) -> Unit,
    onDelete: (String) -> Unit,
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = HopaColor.Surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    spec.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                Pill(
                    when {
                        active -> "In use"
                        installed -> "Installed"
                        else -> formatBytes(spec.bytes)
                    },
                )
            }
            ModelDetails(spec)
            if (!installed) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (spec.downloadable) {
                        FilledTonalButton(
                            onClick = { onDownload(spec) },
                            enabled = !state.busy,
                        ) {
                            Text(
                                if (state.downloadingId == spec.id) {
                                    val percent = state.downloadProgress?.let { (it * 100).toInt() } ?: 0
                                    "Downloading $percent%"
                                } else {
                                    "Download"
                                },
                            )
                        }
                    }
                    TextButton(onClick = onImport) { Text("Import file") }
                }
            }
        }
    }
}

@Composable
private fun InstalledRow(
    title: String,
    subtitle: String,
    spec: ModelSpec?,
    active: Boolean,
    expanded: Boolean,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
    onUse: () -> Unit,
    onUpdate: (() -> Unit)? = null,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = HopaColor.Surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = spec != null, onClick = onToggle)
                    .padding(start = 16.dp, top = 10.dp, bottom = 10.dp, end = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(
                            if (active) HopaColor.Success else HopaColor.TextHint.copy(alpha = 0.4f),
                            CircleShape,
                        ),
                )
                Column(modifier = Modifier
                    .weight(1f)
                    .padding(start = 10.dp)) {
                    Text(title, style = MaterialTheme.typography.bodyLarge, color = HopaColor.TextPrimary)
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = HopaColor.TextHint)
                }
                if (spec != null) {
                    Arrow(expanded)
                }
                if (onUpdate != null) {
                    TextButton(onClick = onUpdate) { Text("Update") }
                }
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Filled.Delete,
                        contentDescription = "Remove $title",
                        tint = HopaColor.TextHint,
                    )
                }
            }
            if (expanded && spec != null) {
                Column(
                    modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ModelDetails(spec)
                    if (active) {
                        Text(
                            "This model answers on-device turns.",
                            style = MaterialTheme.typography.bodySmall,
                            color = HopaColor.Success,
                        )
                    } else {
                        FilledTonalButton(onClick = onUse) { Text("Use this model") }
                    }
                }
            }
        }
    }
}

@Composable
private fun DownloadRow(
    spec: ModelSpec,
    state: LocalModelUiState,
    expanded: Boolean,
    onToggle: () -> Unit,
    onDownload: (ModelSpec) -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = HopaColor.SurfaceAlt),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onToggle)
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(spec.name, style = MaterialTheme.typography.bodyLarge, color = HopaColor.TextPrimary)
                    Text(
                        "${formatBytes(spec.bytes)}  ·  ${spec.license}",
                        style = MaterialTheme.typography.bodySmall,
                        color = HopaColor.TextHint,
                    )
                }
                Arrow(expanded)
                if (state.downloadingId == spec.id) {
                    val percent = state.downloadProgress?.let { (it * 100).toInt() } ?: 0
                    Text("$percent%", style = MaterialTheme.typography.labelLarge, color = HopaColor.TextSecondary)
                } else {
                    FilledTonalButton(onClick = { onDownload(spec) }, enabled = !state.busy) {
                        Text("Download")
                    }
                }
            }
            if (expanded) {
                ModelDetails(
                    spec = spec,
                    modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp),
                )
            }
        }
    }
}

/** The card a row opens in place: what it is good at, bad at, and worth knowing. */
@Composable
private fun ModelDetails(spec: ModelSpec, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            "${spec.license}  ·  ${spec.contextTokens / 1000}k context  ·  ${spec.speedClass}",
            style = MaterialTheme.typography.bodySmall,
            color = HopaColor.TextHint,
        )
        spec.strengths.forEach { line -> Bullet(line, strong = true) }
        spec.weaknesses.forEach { line -> Bullet(line, strong = false) }
        spec.notes.forEach { line ->
            Text(
                line,
                style = MaterialTheme.typography.bodySmall,
                color = HopaColor.TextHint,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun Arrow(expanded: Boolean) {
    Icon(
        imageVector = if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
        contentDescription = if (expanded) "Hide details" else "Show details",
        tint = HopaColor.TextHint,
        modifier = Modifier.padding(horizontal = 6.dp),
    )
}

@Composable
private fun Pill(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = HopaColor.TextSecondary,
        modifier = Modifier
            .background(HopaColor.SurfaceAlt, RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun Bullet(text: String, strong: Boolean) {
    Text(
        (if (strong) "+ " else "− ") + text,
        style = MaterialTheme.typography.bodySmall,
        color = if (strong) HopaColor.TextSecondary else HopaColor.TextHint,
    )
}

@Composable
private fun Notice(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = color)
}

@Composable
private fun SurfaceNote(text: String) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = HopaColor.SurfaceAlt),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = HopaColor.TextSecondary,
            modifier = Modifier.padding(14.dp),
        )
    }
}
