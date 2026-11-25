package com.hopa.agent.turn

import com.hopa.agent.goal.Checkpoint
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.InstalledApp

/**
 * One turn, as every client sees it: a goal, the screen to work on, and what the
 * caller already knows.
 *
 * Everything here is a value the caller decided to pass. The runner reads no
 * settings, no files and no Android APIs; a client that has no memory passes an
 * empty string, and one with no vision leaves [vision] false.
 */
data class TurnRequest(
    val goal: String,
    val device: DevicePort,
    val runId: String,
    val traceId: String,

    // ── What the model is told ──────────────────────────────────────────────
    val history: List<ModelMessage> = emptyList(),
    val memory: String = "",
    val skills: String = "",
    val installedApps: List<InstalledApp> = emptyList(),
    val platform: String = "",
    val vision: Boolean = false,
    /** Typed functions the foreground app publishes, already formatted. */
    val appFunctions: String = "",
    /** True when the client can see and act on this device right now. */
    val phoneAccess: Boolean? = null,
    /** Whether this client has a browser surface for `web.*` actions. */
    val webAvailable: Boolean = false,

    // ── What the turn must reach ────────────────────────────────────────────
    /** The screen showing these when the turn ends is what "done" means. */
    val checkpoints: List<Checkpoint> = emptyList(),

    // ── How the turn is allowed to run ──────────────────────────────────────
    /** Ask for a plan first; the caller shows it and sends a second request. */
    val planFirst: Boolean = false,
    /** The person already approved this goal, so the plan gate is skipped. */
    val planApproved: Boolean = false,
    /** Try the cheap recipe path before the model. */
    val replay: Boolean = true,
    /** Try the canonical-command path before the model. */
    val instantCommands: Boolean = true,
    /** Try the hand-written known-app graphs before the model. */
    val useGraphs: Boolean = true,
    /** When false, a goal the graph does not know is refused instead of handed to the model. */
    val graphFallback: Boolean = true,
    /**
     * Ask the API model when the on-device one cannot answer. Off by default:
     * the flag carries the person's consent, and with it the screen and the goal
     * leave the phone.
     */
    val cloudFallback: Boolean = false,
    /** One deadline for the whole turn, not per step. */
    val timeoutMillis: Long = 120_000,
    /**
     * A local model gets a bounded screen render: a 200-node desktop tree is
     * more prompt than a small CPU model can read inside a turn. 0 keeps the
     * whole screen for API models.
     */
    val screenCharLimit: Int = 0,

    // ── What the surfaces answered ──────────────────────────────────────────
    /** Which source is serving the screen: accessibility, bridge, fallback. */
    val surfaceName: String = "",
    /** False when no source could see the screen; the turn stops and says so. */
    val surfaceAvailable: Boolean = true,
    /** Why the last source failed, for the person-facing explanation. */
    val surfaceError: String = "",
)
