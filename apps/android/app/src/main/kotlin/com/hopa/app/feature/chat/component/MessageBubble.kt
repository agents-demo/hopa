package com.hopa.app.feature.chat.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.ChatMessage

@Composable
fun MessageBubble(message: ChatMessage) {
    val fromUser = message.role == "user"
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = if (fromUser) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Top,
    ) {
        if (fromUser) {
            Surface(
                color = HopaColor.Primary,
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(
                    text = message.text,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    color = HopaColor.OnPrimary,
                    fontSize = 15.sp,
                )
            }
        } else {
            HopaMascot(sizeDp = 26.dp, animate = false)
            Text(
                text = message.text,
                modifier = Modifier.padding(start = 8.dp, top = 2.dp, end = 8.dp),
                color = HopaColor.TextPrimary,
                fontSize = 15.sp,
                lineHeight = 22.sp,
            )
        }
    }
}
