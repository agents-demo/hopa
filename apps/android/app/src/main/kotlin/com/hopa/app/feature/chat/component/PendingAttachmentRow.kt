package com.hopa.app.feature.chat.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.Attachment
import com.hopa.data.sessions.AttachmentRules

/** The attachment waiting in the composer; nothing is sent until the user taps send. */
@Composable
fun PendingAttachmentRow(
    attachment: Attachment,
    onDiscard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(HopaColor.Surface, RoundedCornerShape(14.dp))
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (AttachmentRules.isImage(attachment.mime)) {
            AttachmentPreview(
                attachment = attachment,
                modifier = Modifier.width(56.dp),
                height = 56.dp,
            )
        } else {
            AttachmentPreview(attachment = attachment)
        }
        if (AttachmentRules.isImage(attachment.mime)) {
            Column(modifier = Modifier.weight(1f)) {
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
        } else {
            Box(modifier = Modifier.weight(1f))
        }
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(HopaColor.SurfaceAlt, CircleShape)
                .clickable(onClick = onDiscard),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Default.Close,
                contentDescription = "Remove attachment",
                tint = HopaColor.TextSecondary,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}
