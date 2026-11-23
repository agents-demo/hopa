package com.hopa.feature.chat.component

import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.hopa.ui.component.HopaMascot
import com.hopa.ui.theme.HopaColor
import com.hopa.contracts.chat.ChatMessage
import com.hopa.contracts.chat.MessageProof

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    message: ChatMessage,
    onSpeak: (String) -> Unit = {},
    onRetry: () -> Unit = {},
    onUndo: () -> Unit = {},
    goal: String = "",
    saved: Boolean = false,
    onSaveSkill: (String, List<String>) -> Unit = { _, _ -> },
) {
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
                    Column(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                    ) {
                        message.attachment?.let { attachment ->
                            AttachmentPreview(
                                attachment = attachment,
                                modifier = Modifier.widthIn(max = 220.dp),
                            )
                            if (message.text.isNotBlank()) {
                                Spacer(modifier = Modifier.height(6.dp))
                            }
                        }
                        if (message.text.isNotBlank()) {
                            Text(
                                text = message.text,
                                color = HopaColor.OnPrimary,
                                fontSize = 15.sp,
                            )
                        }
                    }
                }
            } else {
                HopaMascot(sizeDp = 26.dp, animate = false, interactive = false)
                Column(
                    modifier = Modifier.padding(start = 8.dp, top = 2.dp, end = 8.dp),
                ) {
                    Text(
                        text = message.text,
                        color = HopaColor.TextPrimary,
                        fontSize = 15.sp,
                        lineHeight = 22.sp,
                    )
                    message.proof?.takeIf { it.executed > 0 }?.let { proof ->
                        ProofReceipt(
                            proof = proof,
                            goal = goal,
                            saved = saved,
                            onSaveSkill = onSaveSkill,
                        )
                    }
                }
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
                    text = { Text("Undo last exchange") },
                    onClick = {
                        onUndo()
                        menu = false
                    },
                )
                DropdownMenuItem(
                    text = { Text("Retry") },
                    onClick = {
                        onRetry()
                        menu = false
                    },
                )
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

/**
 * The receipt for one answer: a quiet pill under the bubble, never a permanent
 * row. It stays with the message, so switching chats does not erase it, and a
 * plain answer (no steps) has no receipt at all.
 */
@Composable
private fun ProofReceipt(
    proof: MessageProof,
    goal: String,
    saved: Boolean,
    onSaveSkill: (String, List<String>) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Column(modifier = Modifier.padding(top = 6.dp)) {
        Text(
            surfaceLabel(proof.path),
            fontSize = 11.sp,
            color = HopaColor.TextHint,
            modifier = Modifier.padding(start = 2.dp, bottom = 2.dp),
        )
        Surface(
            color = HopaColor.SurfaceAlt,
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.clickable { open = !open },
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    sourceLabel(proof.source) +
                        (if (proof.executed == 1) "1 step" else "${proof.executed} steps") +
                        " \u00B7 ${proof.verified} confirmed \u00B7 " +
                        tokensText(proof.tokens),
                    fontSize = 11.sp,
                    color = HopaColor.TextSecondary,
                )
                Text(
                    if (open) "\u25B4" else "\u25BE",
                    fontSize = 10.sp,
                    color = HopaColor.TextHint,
                    modifier = Modifier.padding(start = 6.dp),
                )
            }
        }
        if (proof.fellBack) {
            Text(
                "Hidden screen wasn't ready; HOPA used your screen.",
                fontSize = 11.sp,
                color = HopaColor.TextHint,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        if (open) {
            Column(
                modifier = Modifier.padding(start = 6.dp, top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    "Ran ${whereText(proof.path)} \u00B7 ${proof.millis / 1000} s",
                    fontSize = 11.sp,
                    color = HopaColor.TextHint,
                )
                if (proof.knowledgeVersion.isNotBlank()) {
                    Text(
                        "Knowledge ${proof.knowledgeVersion.removePrefix("sha256:")}",
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                    )
                }
                proof.steps.forEach { step ->
                    Text(step, fontSize = 12.sp, color = HopaColor.TextSecondary)
                }
                if (saved) {
                    Text(
                        "Saved to Skills",
                        fontSize = 12.sp,
                        color = HopaColor.Success,
                    )
                } else if (goal.isNotBlank()) {
                    Text(
                        "Adds this phrase and these steps to Skills, so the model can reuse them.",
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                    )
                    TextButton(
                        onClick = { onSaveSkill(goal, proof.steps) },
                        contentPadding = PaddingValues(0.dp),
                    ) {
                        Text("Teach this as a skill", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

private fun tokensText(tokens: Int): String =
    if (tokens >= 1_000) String.format("%.1fk tokens", tokens / 1000.0) else "$tokens tokens"

/** What ran the steps, in one word, for the receipt's summary line. */
private fun sourceLabel(source: String): String = when (source) {
    "graph" -> "Anchors \u00B7 "
    "command" -> "Command \u00B7 "
    "recipe" -> "Skill \u00B7 "
    "model" -> "Model \u00B7 "
    else -> ""
}

private fun surfaceLabel(path: String): String = when (path) {
    "background" -> "Hidden screen"
    "bridge" -> "From my computer"
    "accessibility" -> "Your screen"
    else -> "No screen"
}

private fun whereText(path: String): String = when (path) {
    "background" -> "on the hidden screen"
    "bridge" -> "from your computer"
    "accessibility" -> "on your screen"
    else -> "with no screen"
}
