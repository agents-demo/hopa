package com.hopa.data.records

import com.hopa.core.contracts.RunRecord
import com.hopa.core.records.RunChain
import com.hopa.core.records.RunRecordDraft
import com.hopa.core.records.RunRecorder
import com.hopa.data.database.dao.RunRecordDao
import com.hopa.data.database.mapper.RunRecordMapper

class RoomRunRecorder(
    private val dao: RunRecordDao,
) : RunRecorder {
    override suspend fun append(draft: RunRecordDraft): RunRecord {
        val previous = dao.last(draft.runId)?.hash ?: RunChain.SEED
        val record = RunChain.seal(draft, previous)
        dao.insert(RunRecordMapper.entity(record))
        return record
    }

    override suspend fun records(runId: String): List<RunRecord> =
        dao.forRun(runId).map(RunRecordMapper::record)

    override suspend fun all(): List<RunRecord> =
        dao.all().map(RunRecordMapper::record)

    override suspend fun verify(runId: String): Boolean =
        RunChain.verify(records(runId))
}
