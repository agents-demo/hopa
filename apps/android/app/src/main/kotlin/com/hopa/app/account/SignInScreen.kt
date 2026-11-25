package com.hopa.app.account

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.ui.component.HopaMascot
import com.hopa.ui.theme.HopaColor

/**
 * The welcome and sign-in screen.
 *
 * The screen has one job: sign in, or leave for local use without feeling
 * pushed out. Two doors, one card: the account tab and "Continue on this
 * phone". Everything else (wordmark, mascot, privacy line) is a caption, not
 * a paragraph, so it fits a 6-inch phone without a scroll before the keyboard.
 */
@Composable
fun SignInScreen(
    state: AccountUiState,
    onSignIn: (String, String) -> Unit,
    onSignUp: (String, String) -> Unit,
    onSkip: () -> Unit,
) {
    var phone by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var signUp by rememberSaveable { mutableStateOf(false) }

    Scaffold(containerColor = HopaColor.Bg) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "HOPA",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 3.sp,
                color = HopaColor.TextHint,
            )

            Box(
                modifier = Modifier
                    .size(116.dp)
                    .background(
                        Brush.radialGradient(listOf(HopaColor.PrimarySoft, HopaColor.Bg)),
                        CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                HopaMascot(sizeDp = 84.dp, state = "idle")
            }

            Text(
                "Hi, I'm HOPA",
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
                color = HopaColor.TextPrimary,
                textAlign = TextAlign.Center,
            )
            Text(
                "Sign in to connect this phone with your computer. " +
                    "Or continue on this phone.",
                fontSize = 13.sp,
                lineHeight = 18.sp,
                color = HopaColor.TextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 6.dp),
            )

            Surface(
                shape = RoundedCornerShape(24.dp),
                color = HopaColor.Surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, HopaColor.Divider, RoundedCornerShape(24.dp)),
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(HopaColor.SurfaceAlt, RoundedCornerShape(14.dp))
                            .padding(4.dp),
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        AuthTab("Sign in", selected = !signUp) { signUp = false }
                        AuthTab("Create account", selected = signUp) { signUp = true }
                    }

                    OutlinedTextField(
                        value = phone,
                        onValueChange = { phone = it },
                        label = { Text("Phone") },
                        placeholder = { Text("+972 50 123 4567") },
                        singleLine = true,
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("Password") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )

                    state.error?.let { error ->
                        Surface(
                            color = HopaColor.Danger.copy(alpha = 0.08f),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                error,
                                color = HopaColor.Danger,
                                fontSize = 12.sp,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            )
                        }
                    }

                    Button(
                        onClick = {
                            if (signUp) onSignUp(phone, password) else onSignIn(phone, password)
                        },
                        enabled = !state.busy && phone.isNotBlank() && password.isNotBlank(),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = HopaColor.Primary,
                            contentColor = HopaColor.OnPrimary,
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                    ) {
                        if (state.busy) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = HopaColor.OnPrimary,
                            )
                            Text("  Working…", fontSize = 14.sp)
                        } else {
                            Text(
                                if (signUp) "Create account" else "Sign in",
                                fontSize = 14.sp,
                            )
                        }
                    }
                }
            }

            OutlinedButton(
                onClick = onSkip,
                enabled = !state.busy,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(46.dp),
            ) {
                Text(
                    "Continue on this phone",
                    color = HopaColor.TextPrimary,
                    fontSize = 13.5.sp,
                )
            }
            Text(
                "You can sign in later from Capabilities → Account.",
                fontSize = 10.5.sp,
                color = HopaColor.TextHint,
                textAlign = TextAlign.Center,
            )

            Text(
                "Chats stay on this phone. Nothing is sent unless you choose an API or sign in.",
                fontSize = 10.sp,
                lineHeight = 14.sp,
                color = HopaColor.TextHint,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun RowScope.AuthTab(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .weight(1f)
            .background(
                if (selected) HopaColor.Surface else HopaColor.SurfaceAlt,
                RoundedCornerShape(10.dp),
            )
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            fontSize = 12.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) HopaColor.TextPrimary else HopaColor.TextHint,
        )
    }
}
