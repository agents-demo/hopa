package com.hopa.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

@Composable
fun HopaTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val colors = if (dark) {
        darkColorScheme(
            primary = HopaColor.Orange,
            secondary = HopaColor.Blue,
            background = HopaColor.Ink,
            surface = HopaColor.Ink,
        )
    } else {
        lightColorScheme(
            primary = HopaColor.Blue,
            secondary = HopaColor.Orange,
            background = HopaColor.Paper,
            surface = HopaColor.Paper,
            onBackground = HopaColor.Ink,
            onSurface = HopaColor.Ink,
        )
    }
    MaterialTheme(
        colorScheme = colors,
        typography = HopaType.type,
        content = content,
    )
}
