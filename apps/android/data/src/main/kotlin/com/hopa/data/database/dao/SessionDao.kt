package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.SessionEntity

@Dao
interface SessionDao {
    @Query(
        "SELECT * FROM sessions WHERE deletedAt = 0 AND archivedAt = 0 " +
            "ORDER BY pinned DESC, updatedAt DESC",
    )
    suspend fun all(): List<SessionEntity>

    @Query(
        "SELECT DISTINCT s.* FROM sessions s LEFT JOIN turns t ON t.sessionId = s.id " +
            "WHERE s.deletedAt = 0 AND s.archivedAt = 0 AND (" +
            ":query = '' OR s.title LIKE '%' || :query || '%' OR t.text LIKE '%' || :query || '%') " +
            "ORDER BY s.pinned DESC, s.updatedAt DESC",
    )
    suspend fun search(query: String): List<SessionEntity>

    @Query("SELECT * FROM sessions WHERE id = :id LIMIT 1")
    suspend fun byId(id: String): SessionEntity?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(session: SessionEntity)

    @Query("UPDATE sessions SET title = :title, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateMeta(id: String, title: String, updatedAt: Long)

    @Query("UPDATE sessions SET title = :title WHERE id = :id")
    suspend fun rename(id: String, title: String)

    @Query("UPDATE sessions SET deletedAt = :at, updatedAt = :at WHERE id = :id")
    suspend fun tombstone(id: String, at: Long)

    @Query("UPDATE sessions SET deletedAt = 0 WHERE id = :id")
    suspend fun restore(id: String)

    @Query("UPDATE sessions SET pinned = :pinned WHERE id = :id")
    suspend fun setPinned(id: String, pinned: Boolean)

    @Query("UPDATE sessions SET archivedAt = :at, updatedAt = :at WHERE id = :id")
    suspend fun archive(id: String, at: Long)

    @Query("UPDATE sessions SET deletedAt = :at WHERE deletedAt = 0")
    suspend fun tombstoneAll(at: Long)
}
