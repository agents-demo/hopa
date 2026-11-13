package com.hopa.app

import androidx.compose.runtime.Composable
import com.hopa.app.di.AppContainer
import com.hopa.app.navigation.HopaNavHost
import com.hopa.app.ui.theme.HopaTheme

@Composable
fun HopaApp(container: AppContainer) {
    HopaTheme {
        HopaNavHost(container = container)
    }
}
