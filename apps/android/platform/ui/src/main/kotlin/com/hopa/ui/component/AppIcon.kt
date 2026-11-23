package com.hopa.ui.component

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.drawable.toBitmap
import com.hopa.ui.theme.HopaColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The app's own icon when the package is installed, and the catalog's monogram
 * when it is not. A missing app is a normal state here, not an error.
 */
@Composable
fun AppIcon(
    packageName: String,
    label: String,
    size: Dp,
    corner: Dp = 10.dp,
    fallbackTint: Color = HopaColor.Primary,
    fallbackBg: Color = HopaColor.PrimarySoft,
) {
    val context = LocalContext.current
    var icon by remember(packageName) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(packageName) {
        if (packageName.isNotBlank()) {
            icon = withContext(Dispatchers.IO) {
                runCatching {
                    context.packageManager.getApplicationIcon(packageName)
                        .toBitmap(ICON_PX, ICON_PX)
                        .asImageBitmap()
                }.getOrNull()
            }
        }
    }
    val shape = RoundedCornerShape(corner)
    val loaded = icon
    if (loaded != null) {
        Image(
            bitmap = loaded,
            contentDescription = null,
            modifier = Modifier
                .size(size)
                .clip(shape),
        )
    } else {
        Box(
            modifier = Modifier
                .size(size)
                .background(fallbackBg, shape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                label.trim().take(1).uppercase().ifEmpty { "?" },
                fontSize = (size.value * 0.4f).sp,
                fontWeight = FontWeight.Medium,
                color = fallbackTint,
            )
        }
    }
}

private const val ICON_PX = 96
