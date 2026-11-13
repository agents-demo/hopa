package com.hopa.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.bridge.BridgeClient
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as HopaApplication).container
        applyLaunchConfig(intent, container)
        setContent {
            HopaApp(container = container)
        }
    }

    /**
     * Automation hooks for E2E: `--es hopa.bridgeUrl ...` (plus an optional
     * token or pair code) configures the bridge without tapping the settings
     * form. Nothing happens when the extras are absent.
     */
    private fun applyLaunchConfig(intent: Intent, container: AppContainer) {
        val url = intent.getStringExtra(EXTRA_BRIDGE_URL)
        if (url.isNullOrBlank()) {
            return
        }
        lifecycleScope.launch {
            container.settings.update { it.copy(bridgeUrl = url.trim(), useBridge = true) }
            val token = intent.getStringExtra(EXTRA_BRIDGE_TOKEN)
            if (!token.isNullOrBlank()) {
                container.settings.setBridgeToken(token.trim())
            }
            val code = intent.getStringExtra(EXTRA_BRIDGE_PAIR)
            if (!code.isNullOrBlank()) {
                runCatching { BridgeClient(url, "").pair(code.trim()) }
                    .onSuccess { session ->
                        container.settings.setBridgeToken(session.token)
                        container.settings.setBridgeRefresh(session.refresh)
                    }
            }
        }
    }

    private companion object {
        const val EXTRA_BRIDGE_URL = "hopa.bridgeUrl"
        const val EXTRA_BRIDGE_TOKEN = "hopa.bridgeToken"
        const val EXTRA_BRIDGE_PAIR = "hopa.bridgePair"
    }
}
