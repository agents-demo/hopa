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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor

@Composable
fun HopaBottomBar(
    active: String,
    onSelect: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .background(HopaColor.Surface)
            .padding(horizontal = 6.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        HopaTab("Chat", "chat", Icons.Default.ChatBubble, active, onSelect)
        HopaTab("Activity", "activity", Icons.Default.History, active, onSelect)
        HopaTab("Capabilities", "capabilities", Icons.Default.GridView, active, onSelect)
    }
}

@Composable
private fun HopaTab(
    label: String,
    key: String,
    icon: ImageVector,
    active: String,
    onSelect: (String) -> Unit,
) {
    val selected = active == key
    Column(
        modifier = Modifier
            .width(96.dp)
            .clickable { onSelect(key) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .width(48.dp)
                .height(28.dp)
                .background(
                    color = if (selected) HopaColor.PrimarySoft else HopaColor.Surface,
                    shape = RoundedCornerShape(14.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = if (selected) HopaColor.Primary else HopaColor.TextSecondary,
                modifier = Modifier.height(18.dp),
            )
        }
        Text(
            text = label,
            fontSize = 11.sp,
            color = if (selected) HopaColor.Primary else HopaColor.TextSecondary,
        )
    }
}
