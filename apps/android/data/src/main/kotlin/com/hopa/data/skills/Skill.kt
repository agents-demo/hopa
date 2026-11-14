package com.hopa.data.skills

/** One learned phrase → action pair. */
data class Skill(
    val trigger: String,
    val action: String,
)
