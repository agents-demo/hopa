package com.hopa.app.feature.chat.component

import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.ChatMessage

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(message: ChatMessage, onSpeak: (String) -> Unit = {}) {
    val fromUser = message.role == "user"
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var menu by remember { mutableStateOf(false) }

    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    onClick = {},
                    onLongClick = { menu = true },
                )
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
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text("Copy") },
                onClick = {
                    clipboard.setText(AnnotatedString(message.text))
                    menu = false
                },
            )
            DropdownMenuItem(
                text = { Text("Share") },
                onClick = {
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, message.text)
                    }
                    context.startActivity(Intent.createChooser(send, "Share message"))
                    menu = false
                },
            )
            if (!fromUser) {
                DropdownMenuItem(
                    text = { Text("Read aloud") },
                    onClick = {
                        onSpeak(message.text)
                        menu = false
                    },
                )
            }
        }
    }
}
