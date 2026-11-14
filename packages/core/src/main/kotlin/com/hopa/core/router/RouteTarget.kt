package com.hopa.core.router

data class RouteTarget(
    val name: String,
    val display: String,
    val kind: String,
    val bundle: String = "",
    val domains: List<String> = emptyList(),
    val aliases: List<String> = emptyList(),
    val purpose: String = "",
    val actions: List<String> = emptyList(),
)
