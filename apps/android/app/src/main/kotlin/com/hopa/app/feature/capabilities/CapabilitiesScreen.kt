package com.hopa.app.feature.capabilities

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.hopa.capabilities.llm.ProviderState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CapabilitiesScreen(
    provider: ProviderState,
    endpoint: String,
    records: Int,
    apps: Int,
    accessibilityEnabled: Boolean,
    onBack: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenAccessibility: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Capabilities") },
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Model", style = MaterialTheme.typography.titleLarge)
                    Text(provider.label())
                    Text(endpoint, style = MaterialTheme.typography.bodySmall)
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Device", style = MaterialTheme.typography.titleLarge)
                    Text(if (accessibilityEnabled) "Accessibility is on" else "Accessibility is off")
                    Text("The shell, data and gate work offline.", style = MaterialTheme.typography.bodySmall)
                    Button(onClick = onOpenAccessibility) {
                        Text(if (accessibilityEnabled) "Accessibility settings" else "Enable accessibility")
                    }
                }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Data", style = MaterialTheme.typography.titleLarge)
                    Text("$records run records")
                    Text("$apps launchable apps")
                }
            }
            Button(onClick = onOpenLaunchpad) {
                Text("Open Launchpad")
            }
        }
    }
}

private fun ProviderState.label(): String = when (this) {
    ProviderState.CLOUD -> "Cloud model"
    ProviderState.LAN -> "LAN model"
    ProviderState.DEMO -> "Demo model (no key)"
    ProviderState.NO_MODEL -> "No model"
}
