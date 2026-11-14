package com.hopa.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

/**
 * One palette, like HarmonyOS: color.json has no dark variant, so the app does
 * not flip with the system theme.
 */
@Composable
fun HopaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = HopaColor.Primary,
            onPrimary = HopaColor.OnPrimary,
            primaryContainer = HopaColor.PrimarySoft,
            onPrimaryContainer = HopaColor.Primary,
            secondary = HopaColor.Accent,
            background = HopaColor.Bg,
            onBackground = HopaColor.TextPrimary,
            surface = HopaColor.Surface,
            onSurface = HopaColor.TextPrimary,
            surfaceVariant = HopaColor.SurfaceAlt,
            onSurfaceVariant = HopaColor.TextSecondary,
            outline = HopaColor.Divider,
            error = HopaColor.Danger,
        ),
        typography = HopaType.type,
        content = content,
    )
}
