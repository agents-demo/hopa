package com.hopa.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
        }
        applyLaunchConfig(intent, container)
        val goal = goalFrom(intent)
        setContent {
            HopaApp(container = container, initialGoal = goal)
        }
    }

    /**
     * `hopa://ask?text=...` and `ACTION_PROCESS_TEXT` drop the words into the
     * composer; nothing is sent without a tap.
     */
    private fun goalFrom(intent: Intent?): String {
        if (intent == null) {
            return ""
        }
        if (intent.action == Intent.ACTION_PROCESS_TEXT) {
            return intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString().orEmpty()
        }
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        }
        val data = intent.data ?: return ""
        return if (data.scheme == "hopa" && data.host == "ask") {
            data.getQueryParameter("text").orEmpty()
        } else {
            ""
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
