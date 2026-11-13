package com.hopa.app.feature.conversations

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.Conversation
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ConversationsScreen(
    state: ConversationsUiState,
    onBack: () -> Unit,
    onQuery: (String) -> Unit,
    onSelect: (String) -> Unit,
    onNewChat: () -> Unit,
    onRename: (String, String) -> Unit,
    onDelete: (String) -> Unit,
    onUndoDelete: () -> Unit,
    onTogglePin: (Conversation, Boolean) -> Unit,
    onArchive: (String) -> Unit,
    onDeleteAll: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var renameTarget by remember { mutableStateOf<Conversation?>(null) }
    var menuOpen by remember { mutableStateOf(false) }
    var confirmDeleteAll by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = HopaColor.Bg,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("Chats", fontSize = 18.sp, fontWeight = FontWeight.Medium) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onNewChat) {
                        Icon(Icons.Default.Add, contentDescription = "New chat")
                    }
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Default.MoreVert, contentDescription = "More")
                        }
                        DropdownMenu(
                            expanded = menuOpen,
                            onDismissRequest = { menuOpen = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text("Delete all") },
                                onClick = {
                                    menuOpen = false
                                    confirmDeleteAll = true
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            OutlinedTextField(
                value = state.query,
                onValueChange = onQuery,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                placeholder = { Text("Search chats") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(24.dp),
            )
            HorizontalDivider(color = HopaColor.Divider)

            when {
                state.loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Loading…", color = HopaColor.TextHint)
                    }
                }

                state.error != null -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(state.error, color = MaterialTheme.colorScheme.error)
                    }
                }

                state.conversations.isEmpty() -> {
                    EmptyChats(
                        searching = state.query.isNotBlank(),
                        onNewChat = onNewChat,
                    )
                }

                else -> {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        sections(state.conversations).forEach { section ->
                            item(key = "header-${section.title}") {
                                Text(
                                    section.title.uppercase(),
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = HopaColor.TextHint,
                                    modifier = Modifier.padding(
                                        start = 20.dp,
                                        end = 20.dp,
                                        top = 16.dp,
                                        bottom = 6.dp,
                                    ),
                                )
                            }
                            items(section.items, key = Conversation::id) { conversation ->
                                SwipeableRow(
                                    conversation = conversation,
                                    onSelect = { onSelect(conversation.id) },
                                    onRename = { renameTarget = conversation },
                                    onTogglePin = {
                                        onTogglePin(conversation, !conversation.pinned)
                                    },
                                    onArchive = { onArchive(conversation.id) },
                                    onDelete = {
                                        onDelete(conversation.id)
                                        scope.launch {
                                            val result = snackbar.showSnackbar(
                                                message = "Chat deleted",
                                                actionLabel = "Undo",
                                            )
                                            if (result == SnackbarResult.ActionPerformed) {
                                                onUndoDelete()
                                            }
                                        }
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    renameTarget?.let { target ->
        var title by remember(target.id) { mutableStateOf(target.title) }
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            title = { Text("Rename chat") },
            text = {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        onRename(target.id, title)
                        renameTarget = null
                    },
                ) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { renameTarget = null }) { Text("Cancel") }
            },
        )
    }

    if (confirmDeleteAll) {
        AlertDialog(
            onDismissRequest = { confirmDeleteAll = false },
            title = { Text("Delete all chats?") },
            text = { Text("This removes the history from this device. It cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmDeleteAll = false
                        onDeleteAll()
                    },
                ) { Text("Delete", color = HopaColor.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDeleteAll = false }) { Text("Cancel") }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun SwipeableRow(
    conversation: Conversation,
    onSelect: () -> Unit,
    onRename: () -> Unit,
    onTogglePin: () -> Unit,
    onArchive: () -> Unit,
    onDelete: () -> Unit,
) {
    val dismiss = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else {
                false
            }
        },
    )
    SwipeToDismissBox(
        state = dismiss,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(HopaColor.Danger)
                    .padding(end = 24.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = HopaColor.OnPrimary)
            }
        },
    ) {
        ConversationRow(
            conversation = conversation,
            onSelect = onSelect,
            onRename = onRename,
            onTogglePin = onTogglePin,
            onArchive = onArchive,
            onDelete = onDelete,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ConversationRow(
    conversation: Conversation,
    onSelect: () -> Unit,
    onRename: () -> Unit,
    onTogglePin: () -> Unit,
    onArchive: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(HopaColor.Bg)
            .combinedClickable(
                onClick = onSelect,
                onLongClick = { menuOpen = true },
            )
            .padding(start = 20.dp, end = 8.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (conversation.pinned) {
                    Icon(
                        Icons.Default.PushPin,
                        contentDescription = "Pinned",
                        tint = HopaColor.Primary,
                        modifier = Modifier
                            .size(13.dp)
                            .padding(end = 4.dp),
                    )
                }
                Text(
                    conversation.title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                    maxLines = 1,
                )
            }
            Text(
                conversation.messages.lastOrNull()?.text
                    ?.replace('\n', ' ')
                    ?.take(90)
                    ?: "No messages",
                fontSize = 13.sp,
                color = HopaColor.TextSecondary,
                maxLines = 1,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Text(
            timeLabel(conversation.updatedAt),
            fontSize = 11.sp,
            color = HopaColor.TextHint,
            modifier = Modifier.padding(start = 8.dp, end = 2.dp),
        )
        Box {
            IconButton(onClick = { menuOpen = true }) {
                Icon(
                    Icons.Default.MoreVert,
                    contentDescription = "Chat actions",
                    tint = HopaColor.TextHint,
                )
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text(if (conversation.pinned) "Unpin" else "Pin") },
                    onClick = {
                        menuOpen = false
                        onTogglePin()
                    },
                )
                DropdownMenuItem(
                    text = { Text("Rename") },
                    onClick = {
                        menuOpen = false
                        onRename()
                    },
                )
                DropdownMenuItem(
                    text = { Text("Archive") },
                    onClick = {
                        menuOpen = false
                        onArchive()
                    },
                )
                DropdownMenuItem(
                    text = { Text("Delete", color = HopaColor.Danger) },
                    onClick = {
                        menuOpen = false
                        onDelete()
                    },
                )
            }
        }
    }
}

@Composable
private fun EmptyChats(searching: Boolean, onNewChat: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            if (searching) "No matches" else "No chats yet",
            fontSize = 20.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            if (searching) "Try a different word." else "Start a conversation and it will appear here.",
            fontSize = 13.sp,
            color = HopaColor.TextSecondary,
            modifier = Modifier.padding(top = 6.dp),
        )
        if (!searching) {
            Button(
                onClick = onNewChat,
                modifier = Modifier.padding(top = 16.dp),
            ) {
                Text("Start a chat")
            }
        }
    }
}

private data class ChatSection(val title: String, val items: List<Conversation>)

private fun sections(conversations: List<Conversation>): List<ChatSection> {
    val pinned = conversations.filter { it.pinned }
    val rest = conversations.filterNot { it.pinned }
    val today = LocalDate.now()
    val groups = linkedMapOf(
        "Today" to mutableListOf<Conversation>(),
        "Yesterday" to mutableListOf(),
        "Previous 7 days" to mutableListOf(),
        "Older" to mutableListOf(),
    )
    for (conversation in rest) {
        val date = Instant.ofEpochMilli(conversation.updatedAt)
            .atZone(ZoneId.systemDefault())
            .toLocalDate()
        val days = ChronoUnit.DAYS.between(date, today)
        val key = when {
            days <= 0 -> "Today"
            days == 1L -> "Yesterday"
            days <= 7 -> "Previous 7 days"
            else -> "Older"
        }
        groups.getValue(key) += conversation
    }
    val result = mutableListOf<ChatSection>()
    if (pinned.isNotEmpty()) {
        result += ChatSection("Pinned", pinned)
    }
    groups.forEach { (title, items) ->
        if (items.isNotEmpty()) {
            result += ChatSection(title, items)
        }
    }
    return result
}

private fun timeLabel(millis: Long): String {
    if (millis <= 0) {
        return ""
    }
    val dateTime = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault())
    val date = dateTime.toLocalDate()
    val today = LocalDate.now()
    return when (ChronoUnit.DAYS.between(date, today)) {
        0L -> dateTime.format(DateTimeFormatter.ofPattern("HH:mm"))
        1L -> "Yesterday"
        else -> dateTime.format(DateTimeFormatter.ofPattern("MMM d"))
    }
}
