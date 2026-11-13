package com.hopa.data.skills

/** Triggers the user taught HOPA; they ride along in the system prompt. */
interface SkillStore {
    suspend fun all(): List<Skill>

    suspend fun add(trigger: String, action: String)

    suspend fun delete(trigger: String)

    suspend fun clear()

    suspend fun promptText(): String
}
