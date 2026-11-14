package com.hopa.data.skills

import com.hopa.data.database.dao.SkillDao
import com.hopa.data.database.entity.SkillEntity

class RoomSkillStore(
    private val dao: SkillDao,
) : SkillStore {
    override suspend fun all(): List<Skill> =
        dao.all().map { Skill(trigger = it.trigger, action = it.action) }

    override suspend fun add(trigger: String, action: String) {
        val key = trigger.trim()
        val value = action.trim()
        if (key.isEmpty() || value.isEmpty()) {
            return
        }
        dao.insert(
            SkillEntity(trigger = key, action = value, createdAt = System.currentTimeMillis()),
        )
    }

    override suspend fun delete(trigger: String) {
        dao.delete(trigger)
    }

    override suspend fun clear() {
        dao.deleteAll()
    }

    override suspend fun promptText(): String {
        val skills = all()
        if (skills.isEmpty()) {
            return ""
        }
        return "Triggers the user taught you (use the action when the goal matches):\n" +
            skills.joinToString("\n") { "- \"${it.trigger}\" → ${it.action}" }
    }
}
