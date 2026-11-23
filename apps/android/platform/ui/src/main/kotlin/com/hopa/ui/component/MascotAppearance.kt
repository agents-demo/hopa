package com.hopa.ui.component

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * How the mascot is drawn, set once from the person's setting in [com.hopa.app.HopaApp].
 *
 * Two looks: the object on the page (cut out of its studio backdrop, with a
 * contact shadow) or the framed picture the app shipped before. A global like
 * [com.hopa.ui.theme.HopaColor], because the mascot appears in avatars deep
 * inside the tree and threading a parameter through every bubble would be worse.
 */
object MascotAppearance {
    /** Matches the stored default: the cut-out object stands on the page. */
    var framed: Boolean by mutableStateOf(false)
}
