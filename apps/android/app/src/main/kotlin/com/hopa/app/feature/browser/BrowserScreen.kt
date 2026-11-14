package com.hopa.app.feature.browser

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.capabilities.browser.BrowserScripts
import org.json.JSONTokener

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BrowserScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val focus = LocalFocusManager.current
    var address by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf("") }
    var toolsOpen by remember { mutableStateOf(false) }
    var selector by remember { mutableStateOf("") }
    var value by remember { mutableStateOf("") }
    var read by remember { mutableStateOf<String?>(null) }
    var webView by remember { mutableStateOf<WebView?>(null) }

    fun run(script: String, onResult: (String) -> Unit) {
        val view = webView ?: return
        view.evaluateJavascript(script) { raw -> onResult(decodeJs(raw)) }
    }

    fun go() {
        val url = address.trim()
        if (!url.startsWith("https://")) {
            error = "Only https:// pages are allowed"
            return
        }
        error = null
        status = ""
        webView?.loadUrl(url)
    }

    DisposableEffect(Unit) {
        onDispose {
            webView?.stopLoading()
            webView?.destroy()
        }
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
                    "Browser",
                    fontSize = 18.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
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
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("https:// address") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Uri,
                        imeAction = ImeAction.Go,
                    ),
                    keyboardActions = KeyboardActions(
                        onGo = {
                            focus.clearFocus()
                            go()
                        },
                    ),
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = {
                        focus.clearFocus()
                        go()
                    },
                    modifier = Modifier.padding(start = 8.dp),
                ) { Text("Go") }
            }
            error?.let {
                Text(
                    it,
                    fontSize = 12.sp,
                    color = HopaColor.Danger,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TextButton(onClick = {
                    run(BrowserScripts.READ) { text ->
                        read = BrowserScripts.cap(text)
                    }
                }) { Text("Read page") }
                TextButton(onClick = { toolsOpen = !toolsOpen }) {
                    Text(if (toolsOpen) "Hide tools" else "Page tools")
                }
                Text(status, fontSize = 11.sp, color = HopaColor.TextHint)
            }
            if (toolsOpen) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    OutlinedTextField(
                        value = selector,
                        onValueChange = { selector = it },
                        label = { Text("CSS selector, e.g. #q") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = value,
                        onValueChange = { value = it },
                        label = { Text("Text to type") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = {
                                run(BrowserScripts.click(selector)) { status = "click: $it" }
                            },
                            enabled = selector.isNotBlank(),
                        ) { Text("Click") }
                        Button(
                            onClick = {
                                run(BrowserScripts.type(selector, value)) {
                                    status = "type: $it"
                                }
                            },
                            enabled = selector.isNotBlank() && value.isNotBlank(),
                        ) { Text("Type") }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .background(HopaColor.Surface),
            ) {
                AndroidView(
                    factory = { view ->
                        WebView(view).apply {
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            webViewClient = WebViewClient()
                            setBackgroundColor(android.graphics.Color.TRANSPARENT)
                            webView = this
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }

    read?.let { text ->
        AlertDialog(
            onDismissRequest = { read = null },
            title = { Text("Page text (${text.length} chars)") },
            text = {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .fillMaxWidth(),
                ) {
                    Text(text.ifBlank { "The page has no readable text." }, fontSize = 12.sp)
                    if (text.length >= BrowserScripts.MAX_TEXT) {
                        Text(
                            "Capped at ${BrowserScripts.MAX_TEXT} characters.",
                            fontSize = 11.sp,
                            color = HopaColor.Warning,
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { read = null }) { Text("Close") }
            },
        )
    }
}

private fun decodeJs(raw: String): String {
    val trimmed = raw.trim()
    if (trimmed.isEmpty() || trimmed == "null") {
        return ""
    }
    return runCatching {
        JSONTokener(trimmed).nextValue() as? String ?: trimmed
    }.getOrDefault(trimmed)
}
