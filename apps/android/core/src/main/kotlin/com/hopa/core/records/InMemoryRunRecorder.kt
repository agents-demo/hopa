package com.hopa.core.records

import com.hopa.core.contracts.RunRecord

class InMemoryRunRecorder : RunRecorder {
    private val runs = mutableMapOf<String, MutableList<RunRecord>>()

    override suspend fun append(draft: RunRecordDraft): RunRecord {
        val records = runs.getOrPut(draft.runId) { mutableListOf() }
        val prev = records.lastOrNull()?.hash ?: RunChain.SEED
        val record = RunChain.seal(draft, prev)
        records += record
        return record
    }

    override suspend fun records(runId: String): List<RunRecord> =
        runs[runId]?.toList() ?: emptyList()

    override suspend fun all(): List<RunRecord> =
        runs.values.flatten().sortedByDescending { it.timestamp.orEmpty() }

    override suspend fun verify(runId: String): Boolean {
        val records = runs[runId] ?: return true
        return RunChain.verify(records)
    }
}
