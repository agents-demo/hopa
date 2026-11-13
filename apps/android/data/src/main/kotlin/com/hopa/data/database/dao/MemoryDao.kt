package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.MemoryFactEntity

@Dao
interface MemoryDao {
    @Query("SELECT * FROM memory_facts ORDER BY createdAt")
    suspend fun all(): List<MemoryFactEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(row: MemoryFactEntity)

    @Query("DELETE FROM memory_facts WHERE text = :text")
    suspend fun delete(text: String)

    @Query("DELETE FROM memory_facts")
    suspend fun deleteAll()
}
