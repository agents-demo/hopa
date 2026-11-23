package com.hopa.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * The palette every screen reads. The values switch with the theme; HopaTheme
 * swaps the whole set and resets the composition, so a colour read anywhere in
 * the tree is the current one.
 */
object HopaColor {
    internal var palette: HopaPalette = HopaPalettes.light

    val Bg: Color get() = palette.bg
    val Surface: Color get() = palette.surface
    val SurfaceAlt: Color get() = palette.surfaceAlt
    val SurfaceMuted: Color get() = palette.surfaceMuted
    val TextPrimary: Color get() = palette.textPrimary
    val TextSecondary: Color get() = palette.textSecondary
    val TextHint: Color get() = palette.textHint
    val Primary: Color get() = palette.primary
    val PrimarySoft: Color get() = palette.primarySoft
    val OnPrimary: Color get() = palette.onPrimary
    val Accent: Color get() = palette.accent
    val Danger: Color get() = palette.danger
    val Success: Color get() = palette.success
    val Warning: Color get() = palette.warning
    val Divider: Color get() = palette.divider
    val Scrim: Color get() = palette.scrim
}
