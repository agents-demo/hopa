package com.hopa.app.feature.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hopa.feature.settings.LocalModelSection

/** The wired on-device section: view model in, events out, no logic here. */
@Composable
fun OnDeviceModels() {
    val viewModel: LocalModelViewModel = hiltViewModel()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> if (uri != null) viewModel.importRecommended(uri) }

    LocalModelSection(
        state = state,
        onImport = { picker.launch(arrayOf("*/*")) },
        onDownload = viewModel::download,
        onDelete = viewModel::delete,
        onDeleteAll = viewModel::deleteAll,
        onUse = viewModel::use,
        onAcceptLicence = viewModel::acceptLicenceAndDownload,
        onCancelLicence = viewModel::cancelLicence,
    )
}
