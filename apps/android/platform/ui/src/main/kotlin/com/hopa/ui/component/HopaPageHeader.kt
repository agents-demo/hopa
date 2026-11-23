package com.hopa.ui.component

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hopa.ui.theme.HopaColor

/**
 * A page header with a large title, the 2026 shape: the title owns the top of
 * the screen, a back arrow when the page is pushed, an action or two on the
 * right, and a status line under it. Used as a Scaffold's `topBar`, so the
 * status-bar inset is counted exactly once.
 */
@Composable
fun HopaPageHeader(
    title: String,
    onBack: (() -> Unit)? = null,
    status: @Composable (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(top = 4.dp, bottom = 10.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(end = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = HopaColor.TextPrimary,
                    )
                }
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    title,
                    style = MaterialTheme.typography.headlineMedium,
                    color = HopaColor.TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
            } else {
                Text(
                    title,
                    style = MaterialTheme.typography.headlineMedium,
                    color = HopaColor.TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 20.dp),
                )
            }
            actions()
        }
        if (status != null) {
            Box(modifier = Modifier.padding(start = 20.dp, top = 2.dp)) {
                status()
            }
        }
    }
}
