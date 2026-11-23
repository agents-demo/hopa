package com.hopa.privacy

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * "What left your phone" in numbers: how many characters and tokens each turn
 * cost, and which surface it ran on. A promise about privacy is only worth
 * something if it can be read.
 */
object TurnLog {
    private val _entries = MutableStateFlow<List<TurnLogEntry>>(emptyList())
    val entries: StateFlow<List<TurnLogEntry>> = _entries.asStateFlow()

    private var file: TurnLogFile? = null

    /** Called once at start-up so the list survives a restart. */
    fun attach(file: TurnLogFile) {
        this.file = file
        _entries.value = file.load().reversed()
    }

    fun add(entry: TurnLogEntry) {
        _entries.value = (listOf(entry) + _entries.value).take(50)
        file?.append(entry)
    }
}
