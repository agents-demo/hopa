package com.hopa.app.feature.browser

import androidx.compose.runtime.Composable

@Composable
fun BrowserRoute(
    onBack: () -> Unit,
) {
    BrowserScreen(onBack = onBack)
}
