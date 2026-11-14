package com.hopa.app.feature.runs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.core.contracts.RunRecord
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RunsScreen(
    records: List<RunRecord>,
    onBack: () -> Unit,
    onVerify: suspend (String) -> Boolean,
    onClear: suspend () -> Unit,
) {
    var filter by remember { mutableStateOf("All") }
    var selected by remember { mutableStateOf<RunRecord?>(null) }
    var chainOk by remember { mutableStateOf<Boolean?>(null) }
    var confirmClear by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val visible = when (filter) {
        "Payments" -> records.filter { it.classification == "payment" }
        "Failed" -> records.filter { !it.executed }
        else -> records
    }

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
                    "Runs and batches",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                if (records.isNotEmpty()) {
                    TextButton(onClick = { confirmClear = true }) {
                        Text("Clear", color = HopaColor.Danger)
                    }
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                for (option in listOf("All", "Payments", "Failed")) {
                    val selectedChip = filter == option
                    Text(
                        option,
                        fontSize = 12.sp,
                        color = if (selectedChip) HopaColor.OnPrimary else HopaColor.TextSecondary,
                        modifier = Modifier
                            .background(
                                if (selectedChip) HopaColor.Primary else HopaColor.SurfaceAlt,
                                RoundedCornerShape(16.dp),
                            )
                            .clickable { filter = option }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
            }

            if (visible.isEmpty()) {
                Text(
                    if (records.isEmpty()) {
                        "No runs yet. Send a task from Chat; every executed or refused " +
                            "action is recorded."
                    } else {
                        "No runs match this filter."
                    },
                    fontSize = 13.sp,
                    color = HopaColor.TextHint,
                    modifier = Modifier.padding(20.dp),
                )
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(visible, key = { it.hash }) { record ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    chainOk = null
                                    selected = record
                                }
                                .padding(horizontal = 20.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .background(statusColor(record), CircleShape),
                            )
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    record.action.kind,
                                    fontSize = 14.sp,
                                    color = HopaColor.TextPrimary,
                                )
                                Text(
                                    "${record.classification}  \u00b7  " +
                                        if (record.executed) "executed" else "not run",
                                    fontSize = 11.sp,
                                    color = HopaColor.TextHint,
                                )
                            }
                            Text(
                                record.action.kind.substringBefore('.'),
                                fontSize = 10.sp,
                                color = HopaColor.TextHint,
                            )
                        }
                    }
                }
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("Clear all run records?") },
            text = { Text("The audit trail on this device is removed. It cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmClear = false
                        scope.launch { onClear() }
                    },
                ) { Text("Clear", color = HopaColor.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmClear = false }) { Text("Cancel") }
            },
        )
    }

    selected?.let { record ->
        AlertDialog(
            onDismissRequest = { selected = null },
            title = { Text("Run ${record.runId.take(12)}") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Detail("Step", "${record.step}")
                    Detail("Action", record.action.kind)
                    Detail("Classification", record.classification)
                    Detail("Approved", record.approved?.toString() ?: "not asked")
                    Detail("Executed", record.executed.toString())
                    Detail("Verified", record.verified.toString())
                    record.error?.let { Detail("Error", it) }
                    Detail("Hash", record.hash.take(23))
                    chainOk?.let { ok ->
                        Text(
                            if (ok) "Chain: ok" else "Chain: broken",
                            fontSize = 12.sp,
                            color = if (ok) HopaColor.Success else HopaColor.Danger,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch { chainOk = onVerify(record.runId) }
                    },
                ) { Text("Verify chain") }
            },
            dismissButton = {
                TextButton(onClick = { selected = null }) { Text("Close") }
            },
        )
    }
}

@Composable
private fun Detail(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            "$label: ",
            fontSize = 12.sp,
            color = HopaColor.TextHint,
        )
        Text(
            value,
            fontSize = 12.sp,
            color = HopaColor.TextPrimary,
        )
    }
}

private fun statusColor(record: RunRecord) = when {
    record.executed -> HopaColor.Success
    record.error != null -> HopaColor.Danger
    else -> HopaColor.Warning
}
