package com.hopa.app.feature.settings

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.LocalModelHost
import com.hopa.feature.settings.LocalModelUiState
import com.hopa.inference.local.ImportFailure
import com.hopa.inference.local.ImportOutcome
import com.hopa.inference.local.LocalModelCatalogue
import com.hopa.inference.local.LocalModelQuota
import com.hopa.inference.local.LocalModelRecommendation
import com.hopa.inference.local.ModelSpec
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The on-device section: what to offer this phone, what is installed, and the
 * one import or delete the person asked for.
 *
 * A download is three checks before it starts: the licence must be accepted for
 * this exact file (a new hash asks again), the model must fit the quota, and the
 * phone must have the space.
 */
@HiltViewModel
class LocalModelViewModel @Inject constructor(
    private val host: LocalModelHost,
) : ViewModel() {
    private val _state = MutableStateFlow(LocalModelUiState())
    val state: StateFlow<LocalModelUiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            val installed = host.localModels.installed()
            val settings = host.settings.settings.first()
            val recommended = LocalModelRecommendation().recommend(
                ramGb = host.ramGb,
                freeBytes = host.freeBytes,
            )
            val specs = LocalModelCatalogue.models.associateBy { model -> model.id }
            val activeId = settings.activeModelId
                .takeIf { id -> installed.any { it.id == id } }
                ?: installed.maxByOrNull { model -> model.file.lastModified() }?.id.orEmpty()
            val updates = installed.mapNotNull { model ->
                val spec = specs[model.id] ?: return@mapNotNull null
                val current = spec.sha256.isNotBlank() &&
                    !model.file.name.contains(spec.sha256.take(8), ignoreCase = true)
                if (current) model.id else null
            }.toSet()
            _state.update {
                it.copy(
                    recommended = recommended,
                    installed = installed,
                    installedSpecs = specs,
                    activeId = activeId,
                    updates = updates,
                    totalBytes = installed.sumOf { model -> model.bytes },
                    ramGb = host.ramGb,
                    quotaBytes = LocalModelQuota.MAX_BYTES,
                    acceptedLicences = settings.acceptedModelLicences,
                    error = null,
                )
            }
        }
    }

    fun importRecommended(uri: Uri) {
        val spec = _state.value.recommended
        if (spec == null) {
            _state.update { it.copy(error = "This phone has no model that fits its free space.") }
            return
        }
        if (!fits(spec)) {
            return
        }
        _state.update { it.copy(busy = true, error = null, notice = null) }
        viewModelScope.launch {
            val outcome = host.localModels.import(uri, spec)
            _state.update {
                it.copy(busy = false, notice = noticeFor(outcome), error = errorFor(outcome))
            }
            refresh()
        }
    }

    /** Asks for the licence first when this exact file has not been accepted. */
    fun download(spec: ModelSpec) {
        if (!fits(spec)) {
            return
        }
        if (licenceKey(spec) !in _state.value.acceptedLicences) {
            _state.update { it.copy(licenceFor = spec, error = null) }
            return
        }
        startDownload(spec)
    }

    /** The person accepted the licence the dialog showed. */
    fun acceptLicenceAndDownload() {
        val spec = _state.value.licenceFor ?: return
        val key = licenceKey(spec)
        viewModelScope.launch {
            host.settings.update { it.copy(acceptedModelLicences = it.acceptedModelLicences + key) }
            _state.update {
                it.copy(
                    licenceFor = null,
                    acceptedLicences = it.acceptedLicences + key,
                )
            }
            startDownload(spec)
        }
    }

    fun cancelLicence() {
        _state.update { it.copy(licenceFor = null) }
    }

    fun delete(id: String) {
        viewModelScope.launch {
            host.localModels.delete(id)
            _state.update { it.copy(notice = "Model removed.") }
            refresh()
        }
    }

    /**
     * The model that answers the next on-device turn. The engine reads the same
     * setting, so the row marked "In use" and the model that replies never drift.
     */
    fun use(id: String) {
        viewModelScope.launch {
            host.settings.update { it.copy(activeModelId = id) }
            _state.update {
                it.copy(activeId = id, notice = "On-device answers will use this model.")
            }
        }
    }

    fun deleteAll() {
        viewModelScope.launch {
            host.localModels.cleanup(keep = emptySet())
            _state.update { it.copy(notice = "All models removed.") }
            refresh()
        }
    }

    /** Licence plus hash: an updated file has a new hash and asks again. */
    private fun licenceKey(spec: ModelSpec): String = "${spec.id}:${spec.sha256}"

    /** Space and quota in one place, so every path says the same thing. */
    private fun fits(spec: ModelSpec): Boolean {
        if (spec.bytes > host.freeBytes) {
            _state.update { it.copy(error = "Not enough free space for ${spec.name}.") }
            return false
        }
        val current = _state.value
        if (LocalModelQuota.exceeded(current.totalBytes, spec.bytes, current.quotaBytes)) {
            val used = com.hopa.feature.settings.formatBytes(current.totalBytes)
            val quota = com.hopa.feature.settings.formatBytes(current.quotaBytes)
            _state.update {
                it.copy(
                    error = "Models already use $used of $quota. Remove one before adding ${spec.name}.",
                )
            }
            return false
        }
        return true
    }

    private fun startDownload(spec: ModelSpec) {
        _state.update {
            it.copy(
                busy = true,
                downloadingId = spec.id,
                downloadProgress = 0f,
                error = null,
                notice = null,
                licenceFor = null,
            )
        }
        viewModelScope.launch {
            val outcome = host.localModels.download(spec) { read, total ->
                val progress = if (total > 0) read.toFloat() / total else null
                _state.update { current -> current.copy(downloadProgress = progress) }
            }
            _state.update {
                it.copy(
                    busy = false,
                    downloadingId = null,
                    downloadProgress = null,
                    notice = noticeFor(outcome),
                    error = errorFor(outcome),
                )
            }
            refresh()
        }
    }

    private fun noticeFor(outcome: ImportOutcome): String? = when (outcome) {
        is ImportOutcome.Imported -> "Model ready."
        else -> null
    }

    private fun errorFor(outcome: ImportOutcome): String? = when (outcome) {
        is ImportOutcome.Imported -> null
        is ImportOutcome.HashMismatch -> "The file does not match this model; nothing was installed."
        ImportOutcome.TooLarge -> "The file is larger than this model should be."
        ImportOutcome.Empty -> "The file is empty."
        is ImportOutcome.Failed -> when (outcome.reason) {
            ImportFailure.NETWORK ->
                "The download stopped. Tap Download again and it continues where it left off."
            ImportFailure.STORAGE -> "Not enough space to finish this model. Remove a model first."
            ImportFailure.UNSUPPORTED_FILE -> "This file is not a GGUF model. Choose a .gguf file."
            ImportFailure.CORRUPT -> "The file is damaged or incomplete. Download it again."
        }
    }
}
