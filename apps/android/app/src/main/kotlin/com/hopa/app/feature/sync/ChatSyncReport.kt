package com.hopa.app.feature.sync

data class ChatSyncReport(
    val rev: Int,
    val adopted: Int,
    val tombstoned: Int,
    val pulledFallback: Boolean,
)
