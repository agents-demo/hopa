package com.hopa.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key

/**
 * Two palettes, one API. The values are swapped before the tree is rebuilt, and
 * the inner `key` forces that rebuild, because a plain object cannot be observed
 * by Compose. Without the key, a colour read once would keep the old value.
 */
@Composable
fun HopaTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    HopaColor.palette = if (dark) HopaPalettes.dark else HopaPalettes.light

    val scheme = if (dark) {
        darkColorScheme(
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
        colorScheme = scheme,
        typography = HopaType.type,
    ) {
        key(HopaColor.palette) {
            content()
        }
    }
}
