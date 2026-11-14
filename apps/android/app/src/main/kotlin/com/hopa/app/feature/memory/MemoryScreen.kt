package com.hopa.app.feature.memory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.skills.Skill

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryScreen(
    state: MemoryUiState,
    onBack: () -> Unit,
    onAddFact: (String) -> Unit,
    onDeleteFact: (String) -> Unit,
    onAddSkill: (String, String) -> Unit,
    onDeleteSkill: (String) -> Unit,
    onClearAll: () -> Unit,
    onExport: () -> Unit,
) {
    var fact by remember { mutableStateOf("") }
    var trigger by remember { mutableStateOf("") }
    var action by remember { mutableStateOf("") }

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
                    "Memory and Skills",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                if (state.facts.isNotEmpty() || state.skills.isNotEmpty()) {
                    TextButton(onClick = onExport) { Text("Export") }
                    TextButton(onClick = onClearAll) { Text("Clear all") }
                }
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
            Section("MEMORY")
            Text(
                "Facts HOPA keeps with every request. Add one, delete one, or clear all.",
                fontSize = 12.sp,
                color = HopaColor.TextHint,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = fact,
                    onValueChange = { fact = it },
                    label = { Text("A fact to remember") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = {
                        onAddFact(fact)
                        fact = ""
                    },
                    modifier = Modifier.padding(start = 8.dp),
                ) { Text("Add") }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp)),
            ) {
                if (state.facts.isEmpty()) {
                    Text(
                        "Nothing saved yet.",
                        fontSize = 12.sp,
                        color = HopaColor.TextHint,
                        modifier = Modifier.padding(14.dp),
                    )
                } else {
                    state.facts.forEach { saved ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = 14.dp, end = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                saved,
                                fontSize = 13.sp,
                                color = HopaColor.TextPrimary,
                                modifier = Modifier
                                    .weight(1f)
                                    .padding(vertical = 10.dp),
                            )
                            IconButton(onClick = { onDeleteFact(saved) }) {
                                Icon(
                                    Icons.Default.Close,
                                    contentDescription = "Delete fact",
                                    tint = HopaColor.TextHint,
                                )
                            }
                        }
                    }
                }
            }

            Section("SKILLS")
            Text(
                "A phrase and what it should do; both go into the prompt.",
                fontSize = 12.sp,
                color = HopaColor.TextHint,
            )
            OutlinedTextField(
                value = trigger,
                onValueChange = { trigger = it },
                label = { Text("When I say...") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = action,
                onValueChange = { action = it },
                label = { Text("...do this") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = {
                    onAddSkill(trigger, action)
                    trigger = ""
                    action = ""
                },
                enabled = trigger.isNotBlank() && action.isNotBlank(),
            ) { Text("Add skill") }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp)),
            ) {
                if (state.skills.isEmpty()) {
                    Text(
                        "No skills yet.",
                        fontSize = 12.sp,
                        color = HopaColor.TextHint,
                        modifier = Modifier.padding(14.dp),
                    )
                } else {
                    state.skills.forEach { skill ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = 14.dp, end = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                "\"${skill.trigger}\" \u2192 ${skill.action}",
                                fontSize = 13.sp,
                                color = HopaColor.TextPrimary,
                                modifier = Modifier
                                    .weight(1f)
                                    .padding(vertical = 10.dp),
                            )
                            IconButton(onClick = { onDeleteSkill(skill.trigger) }) {
                                Icon(
                                    Icons.Default.Close,
                                    contentDescription = "Delete skill",
                                    tint = HopaColor.TextHint,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Section(label: String) {
    Text(
        label,
        fontSize = 10.sp,
        color = HopaColor.TextHint,
        letterSpacing = 0.6.sp,
        modifier = Modifier.padding(top = 6.dp),
    )
}
