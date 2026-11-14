package com.hopa.app.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
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
    onSave: (String, String, String, String, Boolean, Boolean, String, String, Boolean) -> Unit,
    onTestBridge: (String, String) -> Unit,
    onTestNotification: () -> Unit,
    onTone: (String) -> Unit,
    onChattiness: (String) -> Unit,
    onOpenSelfCheck: () -> Unit,
    onOpenAbout: () -> Unit,
    onPairBridge: (String, String) -> Unit,
    onOpenCapabilities: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenProfiles: () -> Unit,
    onOpenAccessibility: () -> Unit,
) {
    var provider by rememberSaveable { mutableStateOf(state.settings.provider) }
    var endpoint by rememberSaveable { mutableStateOf(state.settings.endpoint) }
    var model by rememberSaveable { mutableStateOf(state.settings.model) }
    var key by rememberSaveable { mutableStateOf("") }
    var notify by rememberSaveable { mutableStateOf(state.settings.notifyAnswers) }
    var web by rememberSaveable { mutableStateOf(state.settings.webEnabled) }
    var bridgeUrl by rememberSaveable { mutableStateOf(state.settings.bridgeUrl) }
    var bridgeKey by rememberSaveable { mutableStateOf("") }
    var pairCode by rememberSaveable { mutableStateOf("") }
    var useBridge by rememberSaveable { mutableStateOf(state.settings.useBridge) }

    LaunchedEffect(state.settings, state.key) {
        provider = state.settings.provider
        endpoint = state.settings.endpoint
        model = state.settings.model
        notify = state.settings.notifyAnswers
        web = state.settings.webEnabled
        bridgeUrl = state.settings.bridgeUrl
        useBridge = state.settings.useBridge
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
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(onClick = onTestNotification) {
                    Text("Send a test notification")
                }
                Text(
                    state.notice ?: "",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Web capability")
                Switch(checked = web, onCheckedChange = { web = it })
            }
            Text("Bridge (PC)", style = MaterialTheme.typography.titleLarge)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Use the bridge for device actions")
                Switch(checked = useBridge, onCheckedChange = { useBridge = it })
            }
            OutlinedTextField(
                value = bridgeUrl,
                onValueChange = { bridgeUrl = it },
                label = { Text("Bridge address, e.g. http://192.168.1.5:8766") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = pairCode,
                onValueChange = { pairCode = it },
                label = { Text("Pair code from the bridge console") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = bridgeKey,
                onValueChange = { bridgeKey = it },
                label = { Text("Bridge token (stored in Keystore)") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(
                    onClick = { onPairBridge(bridgeUrl, pairCode) },
                    enabled = !state.busy,
                ) {
                    Text("Pair")
                }
                Button(
                    onClick = { onTestBridge(bridgeUrl, bridgeKey) },
                    enabled = !state.busy,
                ) {
                    Text("Test bridge")
                }
            }
            Text(
                state.bridgeStatus ?: "adb acts on the PC; the phone just asks.",
                style = MaterialTheme.typography.bodySmall,
            )
            Button(
                onClick = {
                    onSave(
                        provider,
                        endpoint,
                        model,
                        key,
                        notify,
                        web,
                        bridgeUrl,
                        bridgeKey,
                        useBridge,
                    )
                },
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
            Text("Character", style = MaterialTheme.typography.titleLarge)
            Text("Tone", style = MaterialTheme.typography.bodySmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (value in listOf("friendly", "direct")) {
                    val chosen = state.settings.tone == value
                    Text(
                        value,
                        fontSize = 12.sp,
                        color = if (chosen) HopaColor.OnPrimary else HopaColor.TextSecondary,
                        modifier = Modifier
                            .background(
                                if (chosen) HopaColor.Primary else HopaColor.SurfaceAlt,
                                RoundedCornerShape(16.dp),
                            )
                            .clickable { onTone(value) }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
            }
            Text("Length", style = MaterialTheme.typography.bodySmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (value in listOf("short", "balanced", "detailed")) {
                    val chosen = state.settings.chattiness == value
                    Text(
                        value,
                        fontSize = 12.sp,
                        color = if (chosen) HopaColor.OnPrimary else HopaColor.TextSecondary,
                        modifier = Modifier
                            .background(
                                if (chosen) HopaColor.Primary else HopaColor.SurfaceAlt,
                                RoundedCornerShape(16.dp),
                            )
                            .clickable { onChattiness(value) }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
            }
            Button(onClick = onOpenProfiles) {
                Text("Profiles")
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onOpenSelfCheck) { Text("Self-check") }
                Button(onClick = onOpenAbout) { Text("About") }
            }
            Button(onClick = onOpenCapabilities) {
                Text("Capabilities")
            }
            Button(onClick = onOpenAccessibility) {
                Text("Phone access")
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
