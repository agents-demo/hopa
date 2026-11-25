package com.hopa.app.account

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hopa.ui.component.HopaMascot
import com.hopa.ui.theme.HopaColor

/**
 * The launch screen is a door, not a form.
 *
 * The mascot and the name are the only greeting; the form lives in a
 * half-screen sheet behind the primary button. The local path is a small
 * footer link because it is temporary, not the product's main story.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignInScreen(
    state: AccountUiState,
    onSignIn: (String, String) -> Unit,
    onSignUp: (String, String) -> Unit,
    onSkip: () -> Unit,
    onBack: (() -> Unit)? = null,
) {
    var formOpen by rememberSaveable { mutableStateOf(false) }
    var signUp by rememberSaveable { mutableStateOf(false) }
    var phone by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    Scaffold(containerColor = HopaColor.Bg) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp, vertical = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Spacer(modifier = Modifier.weight(1f))

                HopaMascot(sizeDp = 76.dp, state = "idle")
                Text(
                    "HOPA",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.sp,
                    color = HopaColor.TextPrimary,
                )
                Text(
                    "Your assistant",
                    fontSize = 11.5.sp,
                    color = HopaColor.TextHint,
                )

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    onClick = {
                        signUp = false
                        formOpen = true
                    },
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = HopaColor.Primary,
                        contentColor = HopaColor.OnPrimary,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                ) {
                    Text("Sign in", fontSize = 14.sp)
                }

                TextButton(
                    onClick = {
                        signUp = true
                        formOpen = true
                    },
                ) {
                    Text(
                        "New here? Create an account",
                        fontSize = 12.sp,
                        color = HopaColor.Primary,
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    TextButton(
                        onClick = onSkip,
                        modifier = Modifier.height(40.dp),
                    ) {
                        Text(
                            "Continue without an account",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = HopaColor.TextSecondary,
                        )
                    }
                    Text(
                        "You can sign in later",
                        fontSize = 10.5.sp,
                        color = HopaColor.TextHint,
                        textAlign = TextAlign.Center,
                    )
                }
            }

            if (onBack != null) {
                TextButton(
                    onClick = onBack,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(start = 6.dp, top = 2.dp),
                ) {
                    Text(
                        "Back",
                        fontSize = 12.sp,
                        color = HopaColor.TextSecondary,
                    )
                }
            }
        }
    }

    if (formOpen) {
        ModalBottomSheet(
            onDismissRequest = { formOpen = false },
            containerColor = HopaColor.Bg,
        ) {
            AuthForm(
                state = state,
                signUp = signUp,
                phone = phone,
                onPhone = { phone = it },
                password = password,
                onPassword = { password = it },
                onToggleMode = { signUp = !signUp },
                onSubmit = {
                    if (signUp) onSignUp(phone, password) else onSignIn(phone, password)
                },
            )
        }
    }
}

@Composable
private fun AuthForm(
    state: AccountUiState,
    signUp: Boolean,
    phone: String,
    onPhone: (String) -> Unit,
    password: String,
    onPassword: (String) -> Unit,
    onToggleMode: () -> Unit,
    onSubmit: () -> Unit,
) {
    var reveal by rememberSaveable { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            if (signUp) "Create account" else "Sign in",
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            color = HopaColor.TextPrimary,
        )
        Text(
            if (signUp) {
                "Create an account on this phone."
            } else {
                "Use the phone and password you already have."
            },
            fontSize = 12.sp,
            color = HopaColor.TextHint,
        )

        OutlinedTextField(
            value = phone,
            onValueChange = onPhone,
            label = { Text("Phone") },
            placeholder = { Text("+972 50 123 4567") },
            singleLine = true,
            shape = RoundedCornerShape(14.dp),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Phone,
                imeAction = ImeAction.Next,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = password,
            onValueChange = onPassword,
            label = { Text("Password") },
            singleLine = true,
            shape = RoundedCornerShape(14.dp),
            visualTransformation = if (reveal) {
                VisualTransformation.None
            } else {
                PasswordVisualTransformation()
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done,
            ),
            keyboardActions = KeyboardActions(onDone = { onSubmit() }),
            trailingIcon = {
                TextButton(onClick = { reveal = !reveal }) {
                    Text(if (reveal) "Hide" else "Show", fontSize = 11.sp)
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )

        state.error?.let { error ->
            Text(
                error,
                color = HopaColor.Danger,
                fontSize = 12.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HopaColor.Danger.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }

        Button(
            onClick = onSubmit,
            enabled = !state.busy && phone.isNotBlank() && password.isNotBlank(),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = HopaColor.Primary,
                contentColor = HopaColor.OnPrimary,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
        ) {
            if (state.busy) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    strokeWidth = 2.dp,
                    color = HopaColor.OnPrimary,
                )
                Text("  Working…", fontSize = 14.sp)
            } else {
                Text(if (signUp) "Create account" else "Sign in", fontSize = 14.sp)
            }
        }

        TextButton(
            onClick = onToggleMode,
            modifier = Modifier.align(Alignment.CenterHorizontally),
        ) {
            Text(
                if (signUp) "I already have an account" else "Create an account instead",
                fontSize = 12.sp,
                color = HopaColor.Primary,
            )
        }
    }
}
