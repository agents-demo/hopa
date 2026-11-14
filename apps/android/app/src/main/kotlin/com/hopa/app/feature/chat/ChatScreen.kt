package com.hopa.app.feature.chat

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.hopa.app.feature.chat.component.ChatEmptyState
import com.hopa.app.feature.chat.component.Composer
import com.hopa.app.feature.chat.component.MessageBubble
import com.hopa.app.ui.component.ApprovalSheet
import com.hopa.app.ui.component.HopaBottomBar
import com.hopa.app.ui.component.HopaBottomBarEasy
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.ChatMessage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    state: ChatUiState,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onInput: (String) -> Unit,
    onSend: () -> Unit,
    onOption: (String) -> Unit,
    onQuick: (String) -> Unit,
    onApprove: (Boolean) -> Unit,
    onNewChat: () -> Unit,
    onOpenConversations: () -> Unit,
    onStartVoice: () -> Unit,
    onStopVoice: () -> Unit,
    onDismissVoiceError: () -> Unit,
    onSpeak: (String) -> Unit,
    easy: Boolean = false,
    onOpenSettings: () -> Unit = {},
) {
    val messages = state.current?.messages.orEmpty()
    val listState = rememberLazyListState()
    val context = LocalContext.current
    val micPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            onStartVoice()
        }
    }
    val requestMic = {
        if (
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            onStartVoice()
        } else {
            micPermission.launch(Manifest.permission.RECORD_AUDIO)
        }
    }
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.lastIndex)
        }
    }
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                Row(
                    modifier = Modifier
                        .height(44.dp)
                        .clickable(onClick = onOpenConversations)
                        .padding(start = 4.dp, end = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        Icons.Outlined.Schedule,
                        contentDescription = "Chats",
                        tint = HopaColor.TextPrimary,
                        modifier = Modifier.size(19.dp),
                    )
                    Text("Chats", fontSize = 12.sp, color = HopaColor.TextSecondary)
                }
                if (messages.isNotEmpty()) {
                    Text(
                        text = state.current?.title ?: "Chat",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = HopaColor.TextPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                } else {
                    Spacer(modifier = Modifier.weight(1f))
                }
                if (state.error != null) {
                    Row(
                        modifier = Modifier
                            .padding(end = 6.dp)
                            .background(HopaColor.Danger.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                            .clickable { onSelectTab("activity") }
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        HopaMascot(sizeDp = 20.dp, state = "error", interactive = false)
                        Text(
                            "Problem",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = HopaColor.Danger,
                        )
                    }
                }
                if (messages.isNotEmpty()) {
                    Box(
                        modifier = Modifier
                            .size(width = 40.dp, height = 44.dp)
                            .clickable(onClick = onNewChat),
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .background(HopaColor.PrimarySoft, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = "New chat",
                                tint = HopaColor.Primary,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                }
            }
        },
        bottomBar = {
            Column(
                modifier = Modifier
                    .navigationBarsPadding()
                    .imePadding()
                    .background(HopaColor.Bg),
            ) {
                if (state.options.isNotEmpty()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        state.options.forEach { option ->
                            AssistChip(
                                onClick = { onOption(option) },
                                label = { Text(option) },
                            )
                        }
                    }
                }
                Box(
                    modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 10.dp),
                ) {
                    Composer(
                        value = state.input,
                        busy = state.busy,
                        onValueChange = onInput,
                        onSend = onSend,
                        recording = state.recording,
                        transcribing = state.transcribing,
                        onMic = {
                            if (state.recording) {
                                onStopVoice()
                            } else {
                                requestMic()
                            }
                        },
                    )
                }
                if (state.transcribing) {
                    Text(
                        "Transcribing\u2026",
                        fontSize = 11.sp,
                        color = HopaColor.TextHint,
                        modifier = Modifier.padding(start = 20.dp, bottom = 4.dp),
                    )
                }
                state.voiceError?.let { error ->
                    Text(
                        error,
                        fontSize = 11.sp,
                        color = HopaColor.Danger,
                        modifier = Modifier
                            .clickable(onClick = onDismissVoiceError)
                            .padding(start = 20.dp, end = 20.dp, bottom = 4.dp),
                    )
                }
                if (easy) {
                    HopaBottomBarEasy(
                        active = activeTab,
                        onSelect = { key ->
                            if (key == "settings") onOpenSettings() else onSelectTab(key)
                        },
                    )
                } else {
                    HopaBottomBar(
                        active = activeTab,
                        onSelect = onSelectTab,
                    )
                }
            }
        },
    ) { padding ->
        state.pendingApproval?.let { request ->
            ApprovalSheet(
                request = request,
                onDeny = { onApprove(false) },
                onAllow = { onApprove(true) },
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 8.dp),
        ) {
            if (state.busy) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth(),
                    color = HopaColor.Primary,
                    trackColor = HopaColor.PrimarySoft,
                )
            }
            if (messages.isEmpty()) {
                ChatEmptyState(onQuick = onQuick)
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(messages, key = ChatMessage::id) { message ->
                        MessageBubble(message = message, onSpeak = onSpeak)
                    }
                }
            }
            state.error?.let { error ->
                Text(
                    text = error,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                )
            }
        }
    }
}
