package com.hopa.app.feature.conversations

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaBottomBarEasy
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor
import com.hopa.data.sessions.Conversation
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/** The Easy profile's history page: big cards, one tap to open. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EasyHistoryScreen(
    conversations: List<Conversation>,
    active: String,
    onSelectTab: (String) -> Unit,
    onOpen: (String) -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                Text(
                    "History",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
            }
        },
        bottomBar = {
            Column(modifier = Modifier.navigationBarsPadding()) {
                HopaBottomBarEasy(active = active, onSelect = onSelectTab)
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (conversations.isEmpty()) {
                Text(
                    "No chats yet. Start with Talk.",
                    fontSize = 14.sp,
                    color = HopaColor.TextHint,
                    modifier = Modifier.padding(20.dp),
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(conversations, key = Conversation::id) { chat ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                                .clickable { onOpen(chat.id) }
                                .padding(14.dp),
                        ) {
                            Text(
                                chat.title,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Medium,
                                color = HopaColor.TextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                chat.messages.lastOrNull()?.text?.replace('\n', ' ')
                                    ?.take(90) ?: "No messages",
                                fontSize = 13.sp,
                                color = HopaColor.TextSecondary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(top = 3.dp),
                            )
                            Text(
                                timeLabel(chat.updatedAt),
                                fontSize = 11.sp,
                                color = HopaColor.TextHint,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun timeLabel(millis: Long): String {
    if (millis <= 0) {
        return ""
    }
    val time = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault())
    val days = ChronoUnit.DAYS.between(time.toLocalDate(), LocalDate.now())
    return when {
        days == 0L -> "Today " + time.format(DateTimeFormatter.ofPattern("HH:mm"))
        days == 1L -> "Yesterday"
        else -> time.format(DateTimeFormatter.ofPattern("MMM d"))
    }
}
