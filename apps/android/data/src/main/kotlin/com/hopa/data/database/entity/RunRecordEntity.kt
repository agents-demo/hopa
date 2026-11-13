package com.hopa.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "run_records")
data class RunRecordEntity(
    @PrimaryKey val hash: String,
    val runId: String,
    val step: Int,
    val timestamp: String?,
    val traceId: String,
    val actionJson: String,
    val classification: String,
    val approved: Boolean?,
    val observationHash: String,
    val beforeHash: String?,
    val afterHash: String?,
    val verified: Boolean,
    val executed: Boolean,
    val error: String?,
    val prevHash: String,
)
