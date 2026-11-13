package com.hopa.data.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** A phrase that should route to a known action. */
@Entity(tableName = "skills")
data class SkillEntity(
    @PrimaryKey val trigger: String,
    val action: String,
    val createdAt: Long,
)
