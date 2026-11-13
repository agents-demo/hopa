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
            primary = androidx.compose.ui.graphics.Color(0xFF5B8CFF),
            onPrimary = androidx.compose.ui.graphics.Color(0xFF0B1220),
            secondary = androidx.compose.ui.graphics.Color(0xFFFF8A5C),
            background = androidx.compose.ui.graphics.Color(0xFF121110),
            surface = androidx.compose.ui.graphics.Color(0xFF1B1916),
            surfaceVariant = androidx.compose.ui.graphics.Color(0xFF201D19),
            onBackground = androidx.compose.ui.graphics.Color(0xFFF3EFE7),
            onSurface = androidx.compose.ui.graphics.Color(0xFFF3EFE7),
            onSurfaceVariant = androidx.compose.ui.graphics.Color(0xFFB3ACA0),
            error = androidx.compose.ui.graphics.Color(0xFFFF7A6E),
        )
    } else {
        lightColorScheme(
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
        )
    }
    MaterialTheme(
        colorScheme = colors,
        typography = HopaType.type,
        content = content,
    )
}
