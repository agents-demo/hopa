package com.hopa.app.ui.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.core.gate.ApprovalRequest
import com.hopa.app.ui.theme.HopaColor

@Composable
fun ApprovalSheet(
    request: ApprovalRequest,
    onDeny: () -> Unit,
    onAllow: () -> Unit,
) {
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
            }
        },
        confirmButton = {
            TextButton(onClick = onAllow) {
                Text("Allow", color = if (request.isPayment) HopaColor.Danger else HopaColor.Primary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDeny) {
                Text("Deny", color = HopaColor.TextSecondary)
            }
        },
    )
}
