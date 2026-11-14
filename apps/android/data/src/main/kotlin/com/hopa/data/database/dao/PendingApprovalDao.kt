package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.PendingApprovalEntity

@Dao
interface PendingApprovalDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(row: PendingApprovalEntity)

    @Query("DELETE FROM pending_approvals WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM pending_approvals")
    suspend fun deleteAll()

    @Query("SELECT * FROM pending_approvals ORDER BY createdAt")
    suspend fun all(): List<PendingApprovalEntity>
}
