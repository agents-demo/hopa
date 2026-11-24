package com.hopa.stores

/** The profile catalogue shared by the phone and the PC. */
object Profiles {
    val all: List<Profile> = listOf(
        Profile("everyday", "Everyday"),
        Profile("easy", "Easy"),
        Profile("kid", "Kid"),
        Profile("power", "Power"),
        Profile("social", "Social"),
    )

    fun find(key: String): Profile? = all.firstOrNull { it.key == key }
}
