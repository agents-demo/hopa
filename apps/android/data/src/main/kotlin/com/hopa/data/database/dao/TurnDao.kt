package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.TurnEntity

@Dao
interface TurnDao {
    @Query("SELECT * FROM turns WHERE sessionId = :sessionId ORDER BY timestamp, id")
    suspend fun forSession(sessionId: String): List<TurnEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(turn: TurnEntity)

    @Query(
        "DELETE FROM turns WHERE id IN (" +
            "SELECT id FROM turns WHERE sessionId = :sessionId " +
            "ORDER BY timestamp DESC, id DESC LIMIT :count)",
    )
    suspend fun dropLast(sessionId: String, count: Int)
}
