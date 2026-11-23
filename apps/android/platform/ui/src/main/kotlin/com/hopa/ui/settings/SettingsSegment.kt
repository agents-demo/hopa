package com.hopa.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.ui.theme.HopaColor

/**
 * A segmented control: equal cells, one selected, no wrapping. Chips that wrap
 * text onto three lines ("PC bridg / e") look broken; this cannot.
 */
@Composable
fun SettingsSegment(
    options: List<Pair<String, String>>,
    selected: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(HopaColor.SurfaceAlt, RoundedCornerShape(14.dp))
            .padding(3.dp),
    ) {
        options.forEach { (value, title) ->
            val chosen = value == selected
            Text(
                title,
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (chosen) HopaColor.Primary else Color.Transparent,
                        RoundedCornerShape(11.dp),
                    )
                    .clickable { onSelect(value) }
                    .padding(horizontal = 2.dp, vertical = 9.dp),
                fontSize = 12.sp,
                fontWeight = if (chosen) FontWeight.Medium else FontWeight.Normal,
                color = if (chosen) HopaColor.OnPrimary else HopaColor.TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
            )
        }
    }
}
