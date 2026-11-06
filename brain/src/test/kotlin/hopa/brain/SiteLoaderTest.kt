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
        name: xiaohongshu
        display: Xiaohongshu
        domains: [xiaohongshu.com]
        aliases: [小红书, XHS]
        apps: [xiaohongshu]
        validated: pending
        platform: harmonyos
        ---
        # Xiaohongshu

        Open the site and read the page.
    """.trimIndent()

    val site = SiteLoader.parse(sample)
    check(site.name == "xiaohongshu", "name")
    check(site.domains == listOf("xiaohongshu.com"), "domains")
    check(site.aliases.contains("小红书"), "aliases")
    check(site.toEntry().domains == listOf("xiaohongshu.com"), "toEntry")

    var missing = false
    try {
        SiteLoader.parse("---\nname: x\ndisplay: X\nplatform: harmonyos\n---\n")
    } catch (error: SiteFormatException) {
        missing = true
    }
    check(missing, "missing domains is rejected")

    val directory = if (args.isNotEmpty()) {
        Path.of(args[0])
    } else {
        Path.of("brain/knowledge/sites")
    }
    val loaded = SiteLoader.load(directory)
    check(loaded.size == 18, "18 site files")
    check(loaded.all { it.platform == "harmonyos" }, "all harmonyos")
    check(loaded.all { it.domains.isNotEmpty() }, "all have domains")
    check(loaded.any { it.name == "bilibili.com" }, "bilibili present")
    check(loaded.any { it.name == "zhihu.com" }, "zhihu present")

    val store = KnowledgeStore(loaded.map { it.toEntry() })
    check(
        store.byDomain("www.xiaohongshu.com")?.name == "xiaohongshu.com",
        "byDomain resolves the site",
    )

    println("SiteLoaderTest: $passed assertions passed")
}
