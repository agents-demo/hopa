package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.RunRecordEntity

@Dao
interface RunRecordDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(record: RunRecordEntity)

    @Query("SELECT * FROM run_records WHERE runId = :runId ORDER BY step")
    suspend fun forRun(runId: String): List<RunRecordEntity>

    @Query("SELECT * FROM run_records ORDER BY timestamp DESC")
    suspend fun all(): List<RunRecordEntity>

    @Query("SELECT * FROM run_records WHERE runId = :runId ORDER BY step DESC LIMIT 1")
    suspend fun last(runId: String): RunRecordEntity?

    @Query("DELETE FROM run_records")
    suspend fun clearAll()

    @Query(
        "DELETE FROM run_records WHERE rowid NOT IN " +
            "(SELECT rowid FROM run_records ORDER BY rowid DESC LIMIT :keep)",
    )
    suspend fun prune(keep: Int)
}
