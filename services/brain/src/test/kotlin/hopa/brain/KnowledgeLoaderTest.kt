package hopa.brain

import java.nio.file.Path

private var passed = 0

private fun check(condition: Boolean, message: String) {
    if (!condition) throw AssertionError(message)
    passed++
}

fun main(args: Array<String>) {
    val sample = """
        ---
        name: settings
        display: Settings
        bundle: com.huawei.hmos.settings
        aliases: [设置, settings]
        pace: careful
        validated: pending
        platform: harmonyos
        ---
        # Settings

        Open Settings, then Wi-Fi, Bluetooth or Display.
    """.trimIndent()

    val document = KnowledgeLoader.parse(sample)
    check(document.entry.name == "settings", "name")
    check(document.entry.display == "Settings", "display")
    check(document.entry.packages.contains("com.huawei.hmos.settings"), "bundle")
    check(document.entry.aliases.contains("设置"), "alias")
    check(document.pace == "careful", "pace")
    check(document.platform == "harmonyos", "platform")
    check(document.body.contains("Bluetooth"), "body")

    var missing = false
    try {
        KnowledgeLoader.parse("---\nname: x\n---\n")
    } catch (error: KnowledgeFormatException) {
        missing = true
    }
    check(missing, "missing bundle is rejected")

    val unconfirmed = KnowledgeLoader.parse(
        "---\nname: x\ndisplay: X\nbundle: UNCONFIRMED\naliases: [x]\n" +
            "pace: careful\nvalidated: pending\nplatform: harmonyos\n---\n# X\n",
    )
    check(unconfirmed.entry.packages.isEmpty(), "UNCONFIRMED has no launchable package")

    var wrongPlatform = false
    try {
        KnowledgeLoader.parse(
            "---\nname: x\ndisplay: X\nbundle: a.b.c\npace: normal\nvalidated: pending\nplatform: android\n---\n",
        )
    } catch (error: KnowledgeFormatException) {
        wrongPlatform = true
    }
    check(wrongPlatform, "android platform is rejected")

    val directory = if (args.isNotEmpty()) {
        Path.of(args[0])
    } else {
        Path.of("brain/knowledge/apps")
    }
    val loaded = KnowledgeLoader.load(directory)
    check(loaded.size == 27, "27 app files (12 system + 15 Mika)")
    check(loaded.all { it.platform == "harmonyos" }, "all harmonyos")
    check(loaded.all { it.pace.isNotEmpty() }, "all have a pace")
    check(loaded.any { it.entry.name == "clock" }, "clock present")
    check(loaded.any { it.entry.name == "browser" }, "browser present")
    check(loaded.any { it.entry.name == "wechat" }, "wechat present")
    check(
        loaded.first { it.entry.name == "wechat" }.entry.packages.isEmpty(),
        "wechat has no unverified bundle",
    )
    check(loaded.count { it.entry.packages.isEmpty() } == 15, "15 unconfirmed bundles")

    println("KnowledgeLoaderTest: $passed assertions passed")
}
