package com.hopa.app.ui.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.app.ui.theme.HopaColor
import com.hopa.core.gate.ApprovalRequest

@Composable
fun ApprovalSheet(
    request: ApprovalRequest,
    onDeny: () -> Unit,
    onAllow: () -> Unit,
) {
    var understood by remember(request) { mutableStateOf(!request.isPayment) }
    AlertDialog(
        onDismissRequest = onDeny,
        title = {
            Column {
                if (request.isPayment) {
                    Surface(
                        color = HopaColor.Danger.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(8.dp),
                    ) {
                        Text(
                            "PAYMENT",
                            color = HopaColor.Danger,
                            fontSize = 10.sp,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        )
                    }
                }
                Text(
                    request.title,
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(request.body, fontSize = 14.sp, color = HopaColor.TextSecondary)
                if (request.amount.isNotEmpty()) {
                    Text("Amount: ${request.amount}", fontSize = 14.sp)
                }
                if (request.merchant.isNotEmpty()) {
                    Text("Merchant: ${request.merchant}", fontSize = 14.sp)
                }
                if (request.isPayment && request.consequence.isNotEmpty()) {
                    Text(
                        request.consequence,
                        color = HopaColor.Danger,
                        fontSize = 12.sp,
                    )
                }
                Text(
                    "Action: ${request.action.kind}",
                    fontSize = 11.sp,
                    color = HopaColor.TextHint,
                )
                if (request.isPayment) {
                    Row(
                        modifier = Modifier
                            .clickable { understood = !understood }
                            .padding(top = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(
                            checked = understood,
                            onCheckedChange = { understood = it },
                        )
                        Text(
                            "I understand money may leave my account.",
                            fontSize = 12.sp,
                            color = HopaColor.TextPrimary,
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = onAllow,
                enabled = understood,
            ) {
                Text(
                    "Allow",
                    color = when {
                        !understood -> HopaColor.TextHint
                        request.isPayment -> HopaColor.Danger
                        else -> HopaColor.Primary
                    },
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDeny) {
                Text("Deny", color = HopaColor.TextSecondary)
            }
        },
    )
}
