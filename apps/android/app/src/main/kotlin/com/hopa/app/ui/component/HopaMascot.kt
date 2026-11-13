package com.hopa.app.ui.component

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun HopaMascot(
    modifier: Modifier = Modifier,
    sizeDp: Dp = 92.dp,
    animate: Boolean = true,
) {
    val transition = rememberInfiniteTransition(label = "mascot")
    val bob by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "bob",
    )
    Canvas(modifier = modifier.size(sizeDp)) {
        val w = this.size.width
        val h = this.size.height
        val lift = if (animate) bob * h * 0.012f else 0f
        val coral = Brush.linearGradient(
            colors = listOf(Color(0xFFF08A5B), Color(0xFFE8703A)),
            start = Offset(w * 0.30f, h * 0.20f),
            end = Offset(w * 0.72f, h * 0.82f),
        )

        translate(top = lift) {
            drawRoundRect(
                color = Color(0xFFE8703A),
                topLeft = Offset(w * 0.35f, h * 0.82f),
                size = Size(w * 0.09f, h * 0.09f),
                cornerRadius = CornerRadius(w * 0.028f),
            )
            drawRoundRect(
                color = Color(0xFFE8703A),
                topLeft = Offset(w * 0.52f, h * 0.82f),
                size = Size(w * 0.09f, h * 0.09f),
                cornerRadius = CornerRadius(w * 0.028f),
            )
            rotate(degrees = -38f, pivot = Offset(w * 0.73f, h * 0.34f)) {
                drawRoundRect(
                    brush = coral,
                    topLeft = Offset(w * 0.73f, h * 0.25f),
                    size = Size(w * 0.055f, h * 0.14f),
                    cornerRadius = CornerRadius(w * 0.028f),
                )
            }
            drawRoundRect(
                brush = coral,
                topLeft = Offset(w * 0.27f, h * 0.17f),
                size = Size(w * 0.46f, h * 0.66f),
                cornerRadius = CornerRadius(w * 0.14f),
            )
            drawRoundRect(
                color = Color(0xFFFFF9F0),
                topLeft = Offset(w * 0.34f, h * 0.26f),
                size = Size(w * 0.32f, h * 0.45f),
                cornerRadius = CornerRadius(w * 0.08f),
            )
            drawRoundRect(
                color = Color(0xFF1C1B18),
                topLeft = Offset(w * 0.415f, h * 0.40f),
                size = Size(w * 0.05f, h * 0.115f),
                cornerRadius = CornerRadius(w * 0.025f),
            )
            drawRoundRect(
                color = Color(0xFF1C1B18),
                topLeft = Offset(w * 0.545f, h * 0.40f),
                size = Size(w * 0.05f, h * 0.115f),
                cornerRadius = CornerRadius(w * 0.025f),
            )
            val smile = Path().apply {
                moveTo(w * 0.46f, h * 0.575f)
                quadraticBezierTo(w * 0.51f, h * 0.615f, w * 0.56f, h * 0.575f)
            }
            drawPath(
                path = smile,
                color = Color(0xFF1C1B18),
                style = Stroke(width = w * 0.026f, cap = StrokeCap.Round),
            )
        }
    }
}
