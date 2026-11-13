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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.hopa.capabilities.llm.ProviderState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    state: SettingsUiState,
    onBack: () -> Unit,
    onSave: (String, String, String, String, Boolean, Boolean) -> Unit,
    onOpenCapabilities: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenProfiles: () -> Unit,
) {
    var provider by rememberSaveable { mutableStateOf(state.settings.provider) }
    var endpoint by rememberSaveable { mutableStateOf(state.settings.endpoint) }
    var model by rememberSaveable { mutableStateOf(state.settings.model) }
    var key by rememberSaveable { mutableStateOf("") }
    var notify by rememberSaveable { mutableStateOf(state.settings.notifyAnswers) }
    var web by rememberSaveable { mutableStateOf(state.settings.webEnabled) }

    LaunchedEffect(state.settings, state.key) {
        provider = state.settings.provider
        endpoint = state.settings.endpoint
        model = state.settings.model
        notify = state.settings.notifyAnswers
        web = state.settings.webEnabled
        if (key.isEmpty()) {
            key = state.key
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Model", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = provider,
                onValueChange = { provider = it },
                label = { Text("Provider (stub, openai, lan)") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = endpoint,
                onValueChange = { endpoint = it },
                label = { Text("Endpoint") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = model,
                onValueChange = { model = it },
                label = { Text("Model") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = key,
                onValueChange = { key = it },
                label = { Text("API key (stored in Keystore)") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            Text("Provider state: ${state.providerState.label()}")
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Notify when an answer is ready")
                Switch(checked = notify, onCheckedChange = { notify = it })
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Web capability")
                Switch(checked = web, onCheckedChange = { web = it })
            }
            Button(
                onClick = { onSave(provider, endpoint, model, key, notify, web) },
                enabled = !state.busy,
            ) {
                Text(if (state.busy) "Saving\u2026" else "Save")
            }
            if (state.saved) {
                Text("Saved", color = MaterialTheme.colorScheme.primary)
            }
            state.error?.let { error ->
                Text(error, color = MaterialTheme.colorScheme.error)
            }
            Button(onClick = onOpenProfiles) {
                Text("Profiles")
            }
            Button(onClick = onOpenCapabilities) {
                Text("Capabilities")
            }
            Button(onClick = onOpenLaunchpad) {
                Text("Launchpad")
            }
            Text(
                "LAN works without internet when the endpoint is an OpenAI-compatible " +
                    "server on the same network. The shell and the data work offline; " +
                    "answers need a model.",
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

private fun ProviderState.label(): String = when (this) {
    ProviderState.CLOUD -> "cloud"
    ProviderState.LAN -> "LAN"
    ProviderState.DEMO -> "demo"
    ProviderState.NO_MODEL -> "no model"
}
