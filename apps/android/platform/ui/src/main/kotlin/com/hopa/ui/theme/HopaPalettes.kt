package com.hopa.ui.theme

import androidx.compose.ui.graphics.Color

/** The two palettes. The app follows the system theme. */
internal object HopaPalettes {
    val light = HopaPalette(
        bg = Color(0xFFF7F4EE),
        surface = Color(0xFFFFFFFF),
        surfaceAlt = Color(0xFFF3EFE7),
        surfaceMuted = Color(0xFFF1ECE3),
        textPrimary = Color(0xFF1C1B18),
        textSecondary = Color(0xFF6B665C),
        textHint = Color(0xFF9A9488),
        primary = Color(0xFF0A59F7),
        primarySoft = Color(0xFFE8F0FF),
        onPrimary = Color(0xFFFFFFFF),
        accent = Color(0xFFE8703A),
        danger = Color(0xFFC0392B),
        success = Color(0xFF2E7D5B),
        warning = Color(0xFFB26A00),
        divider = Color(0xFFE9E4DA),
        scrim = Color(0x66000000),
    )

    val dark = HopaPalette(
        bg = Color(0xFF101215),
        surface = Color(0xFF191C21),
        surfaceAlt = Color(0xFF22262C),
        surfaceMuted = Color(0xFF262B32),
        textPrimary = Color(0xFFEDEAE4),
        textSecondary = Color(0xFFA9A397),
        textHint = Color(0xFF7C776E),
        primary = Color(0xFF5B8FFF),
        primarySoft = Color(0xFF1B2740),
        onPrimary = Color(0xFF0B1220),
        accent = Color(0xFFF08A5B),
        danger = Color(0xFFEF6E60),
        success = Color(0xFF4FBF97),
        warning = Color(0xFFE0A458),
        divider = Color(0xFF2C3138),
        scrim = Color(0x99000000),
    )
}
