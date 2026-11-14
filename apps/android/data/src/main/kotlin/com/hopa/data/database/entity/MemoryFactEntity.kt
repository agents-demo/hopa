package com.hopa.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** One thing the user asked HOPA to remember. */
@Entity(tableName = "memory_facts")
data class MemoryFactEntity(
    @PrimaryKey val text: String,
    val createdAt: Long,
)
