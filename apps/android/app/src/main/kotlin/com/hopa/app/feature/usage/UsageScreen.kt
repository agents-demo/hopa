package com.hopa.app.feature.usage

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.component.HopaTopBar
import com.hopa.app.ui.theme.HopaColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageScreen(
    state: UsageUiState,
    onBack: () -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = {
            HopaTopBar {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = HopaColor.TextPrimary,
                    )
                }
                Text(
                    "Usage",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.TextPrimary,
                )
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(16.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(16.dp))
                    .padding(18.dp),
            ) {
                Text(
                    "${state.total}",
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                    color = HopaColor.TextPrimary,
                )
                Text(
                    "actions recorded",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("Succeeded", "${state.executed}", HopaColor.Success, Modifier.weight(1f))
                Stat("Failed", "${state.failed}", HopaColor.Danger, Modifier.weight(1f))
                Stat("Payments", "${state.payments}", HopaColor.Warning, Modifier.weight(1f))
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Last 7 days",
                    fontSize = 14.sp,
                    color = HopaColor.TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "${state.lastSevenDays}",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = HopaColor.Primary,
                )
            }

            if (state.topActions.isEmpty()) {
                Text(
                    "No actions yet. Send a task from Chat; every executed or refused " +
                        "action is recorded.",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                    modifier = Modifier.padding(top = 6.dp),
                )
            } else {
                Text(
                    "TOP ACTIONS",
                    fontSize = 10.sp,
                    color = HopaColor.TextHint,
                    letterSpacing = 0.6.sp,
                    modifier = Modifier.padding(top = 6.dp),
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(HopaColor.Surface, RoundedCornerShape(12.dp))
                        .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
                        .padding(horizontal = 14.dp),
                ) {
                    state.topActions.forEach { (kind, count) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                kind,
                                fontSize = 13.sp,
                                color = HopaColor.TextPrimary,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                "$count",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium,
                                color = HopaColor.TextSecondary,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Stat(
    label: String,
    value: String,
    color: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(HopaColor.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, HopaColor.Divider, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            value,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = color,
        )
        Text(
            label,
            fontSize = 10.sp,
            color = HopaColor.TextHint,
        )
    }
}
