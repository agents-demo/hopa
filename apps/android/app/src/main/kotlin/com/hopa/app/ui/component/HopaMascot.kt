package com.hopa.app.ui.component

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun HopaMascot(
    modifier: Modifier = Modifier,
    sizeDp: Dp = 92.dp,
    animate: Boolean = true,
    interactive: Boolean = true,
) {
    var bubble by remember { mutableStateOf(false) }
    var cheer by remember { mutableStateOf(false) }
    var blinking by remember { mutableStateOf(false) }
    var waveAngle by remember { mutableFloatStateOf(45f) }
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
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
    val scale by animateFloatAsState(
        targetValue = if (cheer) 1.06f else 1f,
        animationSpec = tween(durationMillis = 120),
        label = "cheer",
    )

    LaunchedEffect(animate) {
        if (!animate) {
            return@LaunchedEffect
        }
        while (true) {
            delay(4200)
            blinking = true
            delay(150)
            blinking = false
        }
    }

    Box(
        modifier = modifier
            .size(sizeDp)
            .scale(scale)
            .clickable(enabled = interactive) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                scope.launch {
                    for (step in 1..7) {
                        waveAngle = if (step % 2 == 1) 65f else 25f
                        delay(180)
                    }
                    waveAngle = 45f
                }
                cheer = true
                scope.launch {
                    delay(260)
                    cheer = false
                }
                if (sizeDp >= 56.dp) {
                    bubble = true
                    scope.launch {
                        delay(2200)
                        bubble = false
                    }
                }
            },
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val lift = if (animate) (bob - 0.5f) * h * 0.05f else 0f
            val coral = Brush.linearGradient(
                colors = listOf(Color(0xFFF08A5B), Color(0xFFE8703A)),
                start = Offset(w * 0.30f, h * 0.20f),
                end = Offset(w * 0.72f, h * 0.82f),
            )

            translate(top = lift) {
                drawRoundRect(
                    color = Color(0xFFE8703A),
                    topLeft = Offset(w * 0.3516f, h * 0.8242f),
                    size = Size(w * 0.0859f, h * 0.0859f),
                    cornerRadius = CornerRadius(w * 0.0273f),
                )
                drawRoundRect(
                    color = Color(0xFFE8703A),
                    topLeft = Offset(w * 0.5195f, h * 0.8242f),
                    size = Size(w * 0.0859f, h * 0.0859f),
                    cornerRadius = CornerRadius(w * 0.0273f),
                )
                drawRoundRect(
                    brush = coral,
                    topLeft = Offset(w * 0.2734f, h * 0.1719f),
                    size = Size(w * 0.4492f, h * 0.6563f),
                    cornerRadius = CornerRadius(w * 0.1406f),
                )
                drawRoundRect(
                    color = Color(0xFFFFF9F0),
                    topLeft = Offset(w * 0.3379f, h * 0.2539f),
                    size = Size(w * 0.3203f, h * 0.4531f),
                    cornerRadius = CornerRadius(w * 0.0820f),
                )
                val eyeHeight = if (blinking) h * 0.035f else h * 0.1133f
                val eyeTop = if (blinking) h * 0.445f else h * 0.3984f
                drawRoundRect(
                    color = Color(0xFF1C1B18),
                    topLeft = Offset(w * 0.4141f, eyeTop),
                    size = Size(w * 0.0508f, eyeHeight),
                    cornerRadius = CornerRadius(w * 0.0254f),
                )
                drawRoundRect(
                    color = Color(0xFF1C1B18),
                    topLeft = Offset(w * 0.5469f, eyeTop),
                    size = Size(w * 0.0508f, eyeHeight),
                    cornerRadius = CornerRadius(w * 0.0254f),
                )
                val smile = Path().apply {
                    moveTo(w * 0.4609f, h * 0.5703f)
                    quadraticBezierTo(w * 0.5098f, h * 0.6094f, w * 0.5586f, h * 0.5703f)
                }
                drawPath(
                    path = smile,
                    color = Color(0xFF1C1B18),
                    style = Stroke(width = w * 0.0254f, cap = StrokeCap.Round),
                )
                rotate(degrees = waveAngle, pivot = Offset(w * 0.744f, h * 0.381f)) {
                    drawRoundRect(
                        color = HopaColor.Accent,
                        topLeft = Offset(w * 0.713f, h * 0.281f),
                        size = Size(w * 0.062f, h * 0.20f),
                        cornerRadius = CornerRadius(w * 0.031f),
                    )
                }
            }
        }

        if (bubble && sizeDp >= 56.dp) {
            Box(
                modifier = Modifier
                    .offset(x = sizeDp * 0.38f, y = -sizeDp * 1.02f)
                    .requiredWidth(sizeDp * 1.70f)
                    .requiredHeight(sizeDp * 0.99f)
                    .graphicsLayer(rotationZ = -3f),
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val w = size.width
                    val h = size.height
                    val path = bubblePath(w, h)
                    translate(left = w * 0.01f, top = h * 0.05f) {
                        drawPath(path, color = Color(0x1A000000))
                    }
                    translate(left = w * 0.02f, top = h * 0.09f) {
                        drawPath(path, color = Color(0x0F000000))
                    }
                    drawPath(path, color = HopaColor.Accent)
                }
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = sizeDp * 0.20f),
                    contentAlignment = Alignment.TopCenter,
                ) {
                    Text(
                        "Hi, I'm HOPA \uD83D\uDC4B",
                        color = Color.White,
                        fontSize = (sizeDp.value * 0.19f).sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

private fun bubblePath(w: Float, h: Float): Path {
    val sx = w / 240f
    val sy = h / 108f
    fun x(value: Float) = value * sx
    fun y(value: Float) = value * sy
    return Path().apply {
        moveTo(x(36f), y(2f))
        lineTo(x(204f), y(2f))
        arcTo(Rect(x(204f), y(2f), x(238f), y(36f)), -90f, 90f, false)
        lineTo(x(238f), y(44f))
        arcTo(Rect(x(204f), y(44f), x(238f), y(78f)), 0f, 90f, false)
        lineTo(x(118f), y(78f))
        cubicTo(x(104f), y(90f), x(80f), y(100f), x(44f), y(106f))
        cubicTo(x(68f), y(94f), x(78f), y(86f), x(80f), y(78f))
        lineTo(x(36f), y(78f))
        arcTo(Rect(x(2f), y(44f), x(36f), y(78f)), 90f, 90f, false)
        lineTo(x(2f), y(36f))
        arcTo(Rect(x(2f), y(2f), x(36f), y(36f)), 180f, 90f, false)
        close()
    }
}
