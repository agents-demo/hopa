package com.hopa.app.feature.chat.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor

@Composable
fun Composer(
    value: String,
    busy: Boolean,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
) {
    val canSend = value.isNotBlank() && !busy
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp)
            .background(HopaColor.Surface, RoundedCornerShape(26.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(26.dp))
            .padding(start = 14.dp, end = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .weight(1f)
                .onPreviewKeyEvent { event ->
                    if (event.type == KeyEventType.KeyDown && event.key == Key.Enter) {
                        if (event.isShiftPressed) {
                            false
                        } else {
                            if (canSend) {
                                onSend()
                            }
                            true
                        }
                    } else {
                        false
                    }
                },
            textStyle = TextStyle(
                fontSize = 15.sp,
                color = HopaColor.TextPrimary,
            ),
            cursorBrush = SolidColor(HopaColor.Primary),
            maxLines = 3,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            "Ask HOPA...",
                            fontSize = 15.sp,
                            color = HopaColor.TextHint,
                        )
                    }
                    inner()
                }
            },
        )
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(
                    color = when {
                        busy -> HopaColor.Danger
                        canSend -> HopaColor.Primary
                        else -> HopaColor.SurfaceMuted
                    },
                    shape = CircleShape,
                )
                .clickable(enabled = canSend || busy) {
                    when {
                        busy -> Unit
                        canSend -> onSend()
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            when {
                busy -> Icon(
                    Icons.Default.Stop,
                    contentDescription = "Stop",
                    tint = HopaColor.OnPrimary,
                    modifier = Modifier.size(16.dp),
                )

                canSend -> Icon(
                    Icons.Default.ArrowUpward,
                    contentDescription = "Send",
                    tint = HopaColor.OnPrimary,
                    modifier = Modifier.size(20.dp),
                )

                else -> Icon(
                    Icons.Default.Mic,
                    contentDescription = "Speak",
                    tint = HopaColor.TextSecondary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
