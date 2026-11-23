package com.hopa.app.di

import com.hopa.engine.llama.LocalModelStore

/**
 * What the on-device settings page reads.
 *
 * It lives in the app module, next to the container that implements it, for the
 * same reason the other narrow interfaces do: the view model is tested on the
 * JVM with a fake, and no screen sees the whole container.
 */
interface LocalModelHost {
    val localModels: LocalModelStore

    /** Licence acceptance and the rest of the person's settings. */
    val settings: com.hopa.stores.SettingsRepository

    /** Total RAM of this phone, in gigabytes, for the recommendation. */
    val ramGb: Int

    /** Space available to app storage, for the recommendation and the checks. */
    val freeBytes: Long
}
