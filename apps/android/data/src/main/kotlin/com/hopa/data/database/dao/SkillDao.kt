package com.hopa.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.hopa.data.database.entity.SkillEntity

@Dao
interface SkillDao {
    @Query("SELECT * FROM skills ORDER BY createdAt")
    suspend fun all(): List<SkillEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(row: SkillEntity)

    @Query("DELETE FROM skills WHERE `trigger` = :trigger")
    suspend fun delete(trigger: String)

    @Query("DELETE FROM skills")
    suspend fun deleteAll()
}
