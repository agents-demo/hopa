package com.hopa.app.account

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hopa.app.di.AppContainer
import com.hopa.app.link.push.FirebaseToken
import kotlinx.coroutines.launch

/**
 * The sign-in / sign-up screen. Phone + password, one busy flag and one error,
 * and a toggle between signing in and creating an account. On success the
 * stored identity is written and [onSignedIn] moves the app to the home shell.
 */
@Composable
fun SignInRoute(
    container: AppContainer,
    gatewayUrl: String,
    onSignedIn: () -> Unit,
    onBack: (() -> Unit)? = null,
) {
    val viewModel = remember {
        AccountViewModel(
            settings = container.settings,
            gatewayUrl = gatewayUrl,
            deviceName = Build.MODEL,
            pushToken = { FirebaseToken.current() },
        )
    }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    LaunchedEffect(state.signedIn) {
        if (state.signedIn) {
            onSignedIn()
        }
    }
    SignInScreen(
        state = state,
        onSignIn = viewModel::signIn,
        onSignUp = viewModel::signUp,
        onSkip = {
            scope.launch {
                container.settings.update { it.copy(accountSkipped = true) }
                onSignedIn()
            }
        },
        onBack = onBack,
    )
}
