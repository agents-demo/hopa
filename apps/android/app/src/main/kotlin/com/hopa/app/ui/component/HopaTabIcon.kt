package com.hopa.app.ui.component

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.dp
import com.hopa.app.ui.theme.HopaColor

/** The bottom-bar icons, drawn at the Harmony geometry. */
@Composable
fun HopaTabIcon(kind: String, active: Boolean) {
    val color = if (active) HopaColor.Primary else HopaColor.TextSecondary
    Canvas(modifier = Modifier.size(22.dp)) {
        when (kind) {
            "chat", "talk" -> {
                drawRoundRect(
                    color = color,
                    topLeft = Offset(1.dp.toPx(), 2.dp.toPx()),
                    size = Size(20.dp.toPx(), 15.dp.toPx()),
                    cornerRadius = CornerRadius(5.dp.toPx()),
                )
                rotate(degrees = 45f, pivot = Offset(6.dp.toPx(), 16.dp.toPx())) {
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(3.dp.toPx(), 13.dp.toPx()),
                        size = Size(6.dp.toPx(), 6.dp.toPx()),
                        cornerRadius = CornerRadius(1.dp.toPx()),
                    )
                }
            }

            "activity", "history" -> {
                drawCircle(
                    color = color,
                    radius = 9.5.dp.toPx(),
                    center = Offset(11.dp.toPx(), 11.dp.toPx()),
                    style = Stroke(width = 1.8.dp.toPx()),
                )
                drawLine(
                    color = color,
                    start = Offset(11.dp.toPx(), 6.5.dp.toPx()),
                    end = Offset(11.dp.toPx(), 11.dp.toPx()),
                    strokeWidth = 1.8.dp.toPx(),
                )
                drawLine(
                    color = color,
                    start = Offset(11.dp.toPx(), 11.dp.toPx()),
                    end = Offset(15.dp.toPx(), 12.dp.toPx()),
                    strokeWidth = 1.8.dp.toPx(),
                )
            }

            "settings" -> {
                for (row in 0..2) {
                    val y = (5 + row * 6).dp.toPx()
                    val dot = if (row == 1) 9.dp.toPx() else 3.dp.toPx()
                    drawCircle(
                        color = color,
                        radius = 1.8.dp.toPx(),
                        center = Offset(dot, y),
                    )
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(dot + 4.dp.toPx(), y - 1.1.dp.toPx()),
                        size = Size(13.dp.toPx(), 2.2.dp.toPx()),
                        cornerRadius = CornerRadius(1.1.dp.toPx()),
                    )
                }
            }

            else -> {
                val side = 7.dp.toPx()
                val radius = CornerRadius(2.dp.toPx())
                listOf(
                    Offset(2.dp.toPx(), 2.dp.toPx()),
                    Offset(12.dp.toPx(), 2.dp.toPx()),
                    Offset(2.dp.toPx(), 12.dp.toPx()),
                    Offset(12.dp.toPx(), 12.dp.toPx()),
                ).forEach { offset ->
                    drawRoundRect(
                        color = color,
                        topLeft = offset,
                        size = Size(side, side),
                        cornerRadius = radius,
                    )
                }
            }
        }
    }
}
