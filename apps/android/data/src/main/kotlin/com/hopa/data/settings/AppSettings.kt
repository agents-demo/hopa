package com.hopa.data.settings

data class AppSettings(
    val provider: String = "stub",
    val endpoint: String = "https://api.deepseek.com/v1",
    val model: String = "deepseek-v4-flash",
    val profile: String = "everyday",
    val notifyAnswers: Boolean = true,
    val webEnabled: Boolean = true,
    val selectedConversation: String = "",
)
