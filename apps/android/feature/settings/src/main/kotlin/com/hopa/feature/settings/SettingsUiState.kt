package com.hopa.feature.settings

import com.hopa.backend.link.BackendTaskState
import com.hopa.backend.link.BackendState
import com.hopa.inference.choice.ProviderState
import com.hopa.stores.AppSettings

data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val key: String = "",
    /** True when a key is on disk, even if it cannot be decrypted. */
    val keySaved: Boolean = false,
    val bridgeKey: String = "",
    val providerState: ProviderState = ProviderState.DEMO,
    val busy: Boolean = false,
    val saved: Boolean = false,
    val error: String? = null,
    val bridgeStatus: String? = null,
    val notice: String? = null,
    /** The last "Test the model" outcome, shown next to the button. */
    val modelTest: String? = null,
    /** Results of the screen-access self-check, each with its next action. */
    val screenCheck: List<ScreenCheck> = emptyList(),
    /** True when the accessibility service is enabled and bound now. */
    val phoneAccess: Boolean = false,
    /** True when the hidden-display helper answers on loopback now. */
    val backgroundRunning: Boolean = false,
    /** The gateway this phone talks to, and the identity it paired as. */
    val backendUrl: String = "",
    val backendDeviceId: String = "",
    val backendState: BackendState = BackendState.Disconnected,
    /** The FCM registration, never shown whole. */
    val backendToken: String? = null,
    val fcmAvailable: Boolean = false,
    /** What the gateway last asked this phone to run. */
    val backendTask: BackendTaskState = BackendTaskState(),
    /** The label a launch config gave this phone, if any. */
    val backendName: String = "",
    /** The approval signing key's fingerprint, to compare with the PC's log; blank before pairing. */
    val approvalKeyFingerprint: String = "",
    /** The last pairing attempt's answer, shown under the card's buttons. */
    val backendStatus: String? = null,
    /** The layers this build ships, for the Decisions page. */
    val decisionLayers: List<DecisionLayerInfo> = emptyList(),
    /** Who decides now for read, change and dangerous actions; `model` when none. */
    val decisionActive: Map<String, String> = emptyMap(),
    /** One line per known app and its graphs. */
    val graphPaths: List<String> = emptyList(),
    /** The model files on this phone, for the picker on Act. */
    val installedModels: List<ModelOption> = emptyList(),
    /** The optional tree ranker: downloaded, downloading, or absent. */
    val treeRankerReady: Boolean = false,
    val treeRankerBusy: Boolean = false,
    /** 0..100 while downloading; null when the size is not known yet. */
    val treeRankerProgress: Int? = null,
)

/** An installed on-device model as the picker shows it. */
data class ModelOption(
    val id: String,
    val label: String,
    val bytes: Long,
)
