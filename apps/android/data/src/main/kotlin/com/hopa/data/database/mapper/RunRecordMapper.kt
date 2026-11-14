package com.hopa.data.database.mapper

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.RunRecord
import com.hopa.core.json.HopaJson
import com.hopa.data.database.entity.RunRecordEntity

object RunRecordMapper {
    fun entity(record: RunRecord): RunRecordEntity = RunRecordEntity(
        hash = record.hash,
        runId = record.runId,
        step = record.step,
        timestamp = record.timestamp,
        traceId = record.traceId,
        actionJson = HopaJson.element.encodeToString(Action.serializer(), record.action),
        classification = record.classification,
        approved = record.approved,
        observationHash = record.observationHash,
        beforeHash = record.beforeHash,
        afterHash = record.afterHash,
        verified = record.verified,
        executed = record.executed,
        error = record.error,
        prevHash = record.prevHash,
    )

    fun record(entity: RunRecordEntity): RunRecord = RunRecord(
        runId = entity.runId,
        step = entity.step,
        timestamp = entity.timestamp,
        traceId = entity.traceId,
        action = HopaJson.element.decodeFromString(Action.serializer(), entity.actionJson),
        classification = entity.classification,
        approved = entity.approved,
        observationHash = entity.observationHash,
        beforeHash = entity.beforeHash,
        afterHash = entity.afterHash,
        verified = entity.verified,
        executed = entity.executed,
        error = entity.error,
        prevHash = entity.prevHash,
        hash = entity.hash,
    )
}
