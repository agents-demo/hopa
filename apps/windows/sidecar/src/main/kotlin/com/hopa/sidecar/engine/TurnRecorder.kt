package com.hopa.sidecar.engine

import com.hopa.contracts.wire.RunRecord
import com.hopa.runlog.record.RunRecordDraft
import com.hopa.runlog.store.RunRecorder

/** Emits each sealed record as it happens; the chain still lives in the inner recorder. */
internal class EmittingRecorder(
    private val inner: RunRecorder,
    private val onRecord: (Int, RunRecord) -> Unit,
) : RunRecorder by inner {
    private var index = 0

    override suspend fun append(draft: RunRecordDraft): RunRecord {
        val record = inner.append(draft)
        onRecord(index, record)
        index += 1
        return record
    }
}
