package com.hopa.app.ui.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor

/** The Easy profile bar: Talk / History / Settings. */
@Composable
fun HopaBottomBarEasy(
    active: String,
    onSelect: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Surface),
    ) {
        HorizontalDivider(thickness = 1.dp, color = HopaColor.Divider)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(start = 6.dp, end = 6.dp, top = 4.dp, bottom = 6.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            EasyTab("Talk", "talk", active, onSelect, Modifier.weight(1f))
            EasyTab("History", "history", active, onSelect, Modifier.weight(1f))
            EasyTab("Settings", "settings", active, onSelect, Modifier.weight(1f))
        }
    }
}

@Composable
private fun EasyTab(
    label: String,
    key: String,
    active: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val selected = active == key
    Column(
        modifier = modifier.clickable { onSelect(key) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .width(48.dp)
                .height(28.dp)
                .background(
                    color = if (selected) HopaColor.PrimarySoft else Color.Transparent,
                    shape = RoundedCornerShape(14.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            HopaTabIcon(kind = key, active = selected)
        }
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
            color = if (selected) HopaColor.Primary else HopaColor.TextSecondary,
        )
    }
}
