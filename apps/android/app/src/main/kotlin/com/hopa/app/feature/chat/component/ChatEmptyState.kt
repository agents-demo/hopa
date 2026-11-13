package com.hopa.app.feature.chat.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaMascot
import com.hopa.app.ui.theme.HopaColor
import java.util.Calendar

@Composable
fun ChatEmptyState(onQuick: (String) -> Unit) {
    var ideasOpen by remember { mutableStateOf(false) }
    val suggestions = listOf(
        "Open Bilibili and show me the 3 most popular videos",
        "Open Settings and show me Wi-Fi",
        "Draft a one-line message to my team",
    )
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        HopaMascot(sizeDp = 92.dp)
        Text(
            text = greeting(),
            fontSize = 11.sp,
            color = HopaColor.TextHint,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            text = "HOPA",
            style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = "Your assistant. Ask for anything.",
            fontSize = 14.sp,
            color = HopaColor.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            text = "Payments always ask first.",
            fontSize = 11.sp,
            color = HopaColor.TextHint,
            modifier = Modifier.padding(top = 2.dp),
        )

        if (ideasOpen) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 18.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    "TRY SOMETHING",
                    fontSize = 9.sp,
                    color = HopaColor.TextHint,
                    letterSpacing = 0.7.sp,
                )
                suggestions.forEach { suggestion ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                ideasOpen = false
                                onQuick(suggestion)
                            },
                        color = HopaColor.Surface,
                        shape = RoundedCornerShape(12.dp),
                        shadowElevation = 2.dp,
                    ) {
                        Text(
                            suggestion,
                            fontSize = 13.sp,
                            color = HopaColor.TextPrimary,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                        )
                    }
                }
            }
        }

        Row(
            modifier = Modifier.padding(top = 18.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Pill(
                text = if (ideasOpen) "Hide examples \u2193" else "Try an example \u2191",
                onClick = { ideasOpen = !ideasOpen },
            )
            Pill(
                text = "Morning brief?",
                onClick = { onQuick("What should I get done today?") },
            )
        }
    }
}

@Composable
private fun Pill(text: String, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        color = HopaColor.SurfaceAlt,
        shape = RoundedCornerShape(20.dp),
    ) {
        Text(
            text,
            fontSize = 12.5.sp,
            color = if (text.startsWith("Try") || text.startsWith("Hide")) {
                HopaColor.Primary
            } else {
                HopaColor.TextSecondary
            },
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
        )
    }
}

private fun greeting(): String {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    return when {
        hour in 5..11 -> "Good morning"
        hour in 12..17 -> "Good afternoon"
        else -> "Good evening"
    }
}
