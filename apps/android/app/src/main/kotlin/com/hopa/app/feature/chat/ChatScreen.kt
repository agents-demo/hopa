package com.hopa.app.feature.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.feature.chat.component.ChatEmptyState
import com.hopa.app.feature.chat.component.Composer
import com.hopa.app.feature.chat.component.MessageBubble
import com.hopa.app.ui.component.ApprovalSheet
import com.hopa.app.ui.component.HopaBottomBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.ChatMessage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    state: ChatUiState,
    onInput: (String) -> Unit,
    onSend: () -> Unit,
    onOption: (String) -> Unit,
    onQuick: (String) -> Unit,
    onApprove: (Boolean) -> Unit,
    onNewChat: () -> Unit,
    onOpenConversations: () -> Unit,
    onOpenActivity: () -> Unit,
    onOpenCapabilities: () -> Unit,
) {
    val messages = state.current?.messages.orEmpty()
    val listState = rememberLazyListState()
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.lastIndex)
        }
    }
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = HopaColor.Bg,
                ),
                navigationIcon = {
                    Row(
                        modifier = Modifier
                            .height(44.dp)
                            .clickable(onClick = onOpenConversations)
                            .padding(start = 4.dp, end = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Icon(
                            Icons.Default.Schedule,
                            contentDescription = "Chats",
                            tint = HopaColor.TextPrimary,
                            modifier = Modifier.size(19.dp),
                        )
                        Text("Chats", fontSize = 12.sp, color = HopaColor.TextSecondary)
                    }
                },
                title = {
                    if (messages.isNotEmpty()) {
                        Text(
                            text = state.current?.title ?: "Chat",
                            fontSize = 16.sp,
                            color = HopaColor.TextPrimary,
                            maxLines = 1,
                        )
                    }
                },
                actions = {
                    if (state.error != null) {
                        Row(
                            modifier = Modifier
                                .padding(end = 8.dp)
                                .background(HopaColor.Danger.copy(alpha = 0.10f), RoundedCornerShape(10.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text("Problem", fontSize = 10.sp, color = HopaColor.Danger)
                        }
                    }
                    if (messages.isNotEmpty()) {
                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .background(HopaColor.PrimarySoft, CircleShape)
                                .clickable(onClick = onNewChat),
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
                },
            )
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
                    )
                }
                HopaBottomBar(
                    active = "chat",
                    onSelect = { key ->
                        when (key) {
                            "activity" -> onOpenActivity()
                            "capabilities" -> onOpenCapabilities()
                        }
                    },
                )
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
                        MessageBubble(message = message)
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
