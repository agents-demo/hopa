package com.hopa.app.feature.chat.component

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.Attachment
import com.hopa.data.sessions.AttachmentRules
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** An image thumbnail or a file chip for one shared attachment. */
@Composable
fun AttachmentPreview(
    attachment: Attachment,
    modifier: Modifier = Modifier,
    height: Dp = 132.dp,
) {
    if (AttachmentRules.isImage(attachment.mime)) {
        val bitmap by produceState<Bitmap?>(initialValue = null, attachment.path) {
            value = withContext(Dispatchers.IO) { decode(attachment.path) }
        }
        val image = bitmap
        if (image != null) {
            Image(
                bitmap = image.asImageBitmap(),
                contentDescription = attachment.name,
                modifier = modifier
                    .height(height)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop,
            )
        } else {
            FileChip(attachment, modifier)
        }
    } else {
        FileChip(attachment, modifier)
    }
}

@Composable
private fun FileChip(attachment: Attachment, modifier: Modifier) {
    Row(
        modifier = modifier
            .background(HopaColor.SurfaceAlt, RoundedCornerShape(10.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            Icons.Outlined.InsertDriveFile,
            contentDescription = null,
            tint = HopaColor.TextSecondary,
            modifier = Modifier.size(18.dp),
        )
        Column {
            Text(
                attachment.name,
                fontSize = 12.sp,
                color = HopaColor.TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "${AttachmentRules.humanSize(attachment.bytes)} \u00B7 ${attachment.mime}",
                fontSize = 10.sp,
                color = HopaColor.TextHint,
                maxLines = 1,
            )
        }
    }
}

private fun decode(path: String): Bitmap? = runCatching {
    val options = BitmapFactory.Options().apply { inSampleSize = 2 }
    BitmapFactory.decodeFile(path, options)
}.getOrNull()
