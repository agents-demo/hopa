package com.hopa.stores

/**
 * The gateway a fresh install points at. Pairing replaces it with the address
 * carried by the hopa://pair link, and Disconnect restores this value.
 */
const val DEFAULT_BACKEND_URL = "wss://hopa-backend-test.onrender.com/v1/gateway"

data class AppSettings(
    val provider: String = "stub",
    val endpoint: String = "https://api.deepseek.com/v1",
    val model: String = "deepseek-v4-flash",
    /** Which installed model file answers when the provider is `on-device`. */
    val activeModelId: String = "",
    val profile: String = "everyday",
    val notifyAnswers: Boolean = true,
    val selectedConversation: String = "",
    val bridgeUrl: String = "",
    val useBridge: Boolean = true,
    val accessibilityAllowed: Boolean = true,
    val tone: String = "friendly",
    val chattiness: String = "balanced",
    /** auto, background, onscreen or bridge; auto is the only one a user needs. */
    val screenPath: String = "auto",
    /** Show the numbered plan and wait for one approval before acting. */
    val planFirst: Boolean = false,
    /** Repeat a goal that worked before without asking the model. */
    val replaySkills: Boolean = true,
    /** Run a recognized command (open, back, home, scroll, wait) without a model. */
    val instantCommands: Boolean = true,
    /**
     * Where a step comes from: `auto` (a graph for known apps, the model
     * otherwise), `model` (the model only) or `graph` (graphs only).
     */
    val stepSource: String = "auto",
    /**
     * When the on-device model is not sure, ask the API model with the same
     * request. Off by default: it means the screen and the goal leave the phone.
     */
    val cloudFallback: Boolean = false,
    /** Attach a screenshot to each model call (needs a model that sees images). */
    val vision: Boolean = false,
    /**
     * The cut-out mascot on the page is the default. The framed plush picture
     * stays as the opt-in look for anyone who prefers the badge.
     */
    val mascotFramed: Boolean = false,
    /** Packages whose typed calls, messages and closing skip the question. */
    val trustedApps: Set<String> = emptySet(),
    /**
     * Which decision layer decides: `off` (the model, as before), `auto` (the
     * best allowed layer per action class) or a layer id. An unknown id falls
     * back to auto with a notice, never to a silent change of what executes.
     */
    val decisionMode: String = "off",
    /** Record what the layers that were not applied would have decided. */
    val shadowDecisions: Boolean = false,
    /**
     * Model licences the person accepted, as `id:sha256`. A re-downloaded or
     * updated file has a different hash and asks again.
     */
    val acceptedModelLicences: Set<String> = emptySet(),
    /** Address of the gateway this device is paired with. */
    val backendUrl: String = DEFAULT_BACKEND_URL,
    /** Identity this device was given when it joined the household. */
    val backendDeviceId: String = "",
    val backendHouseholdId: String = "",
)
