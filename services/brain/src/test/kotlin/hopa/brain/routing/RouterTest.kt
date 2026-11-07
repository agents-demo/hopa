package hopa.brain.routing

private var passed = 0

private fun check(condition: Boolean, message: String) {
    if (!condition) throw AssertionError(message)
    passed++
}

fun main() {
    val settings = KnowledgeEntry(
        name = "settings",
        display = "Settings",
        aliases = listOf("设置"),
        packages = listOf("com.huawei.hmos.settings"),
        packageAliases = mapOf("settings" to "com.huawei.hmos.settings"),
    )
    val clock = KnowledgeEntry(
        name = "clock",
        display = "Clock",
        aliases = listOf("闹钟", "时钟"),
        packages = listOf("com.huawei.hmos.clock"),
    )
    val xiaohongshu = KnowledgeEntry(
        name = "xiaohongshu",
        display = "Xiaohongshu",
        aliases = listOf("小红书", "xhs"),
        packages = listOf("com.xingin.xhs"),
        domains = listOf("xiaohongshu.com"),
        service = "xiaohongshu",
    )
    val amazon = KnowledgeEntry(
        name = "amazon",
        display = "Amazon",
        aliases = listOf("亚马逊"),
        domains = listOf("amazon.com"),
        service = "amazon",
    )
    val notes = KnowledgeEntry(
        name = "notes",
        display = "Notes",
        aliases = listOf("notes"),
        packages = listOf("com.huawei.hmos.notepad"),
    )
    val notepad = KnowledgeEntry(
        name = "notepad",
        display = "Notepad",
        aliases = listOf("notes"),
        packages = listOf("com.huawei.hmos.notepad2"),
    )
    val wechat = KnowledgeEntry(
        name = "wechat",
        display = "WeChat",
        aliases = listOf("微信"),
        packages = emptyList(),
    )

    val store = KnowledgeStore(listOf(settings, clock, xiaohongshu, amazon, notes, notepad, wechat))

    check(store.matchTask("打开设置").firstOrNull()?.name == "settings", "Chinese alias")
    check(store.matchTask("open clock").firstOrNull()?.name == "clock", "English display")
    check(
        store.matchTask("xiaohongshu.com").firstOrNull()?.name == "xiaohongshu",
        "domain match",
    )
    check(
        store.matchTask("com.xingin.xhs").firstOrNull()?.name == "xiaohongshu",
        "package match",
    )
    check(store.matchTask("app").isEmpty(), "generic word: app")
    check(store.matchTask("web").isEmpty(), "generic word: web")
    check(store.matchTask("browser").isEmpty(), "generic word: browser")
    check(store.matchTask("zzz").isEmpty(), "unknown task")
    check(store.matchTask("xsettingsx").isEmpty(), "word boundary")
    check(store.matchTask("notes", limit = 2).size == 2, "two plausible matches")
    check(store.matchTask("wechat").firstOrNull()?.name == "wechat", "unconfirmed app matches")
    check(store.packageFor("wechat") == null, "unconfirmed app has no package")

    check(store.packageFor("设置") == "com.huawei.hmos.settings", "packageFor alias")
    check(store.packageFor("settings") == "com.huawei.hmos.settings", "packageFor map")
    check(store.byDomain("www.xiaohongshu.com")?.name == "xiaohongshu", "byDomain")
    check(store.byPackage("com.huawei.hmos.clock")?.name == "clock", "byPackage")

    val installedLine = ChannelAdvisor.line(
        listOf(settings),
        ChannelFacts(installed = setOf("com.huawei.hmos.settings")),
    )
    check(
        installedLine == "Available channels: Settings - app: installed (com.huawei.hmos.settings)",
        "channel: installed app",
    )
    val webLine = ChannelAdvisor.line(
        listOf(xiaohongshu),
        ChannelFacts(webAvailable = true, loggedInSites = setOf("xiaohongshu.com")),
    )
    check(webLine != null && webLine.contains("signed in"), "channel: signed in")
    val appOnly = ChannelAdvisor.line(
        listOf(xiaohongshu),
        ChannelFacts(webAvailable = false),
    )
    check(
        appOnly == "Available channels: Xiaohongshu - app: not installed",
        "channel: app only",
    )

    println("RouterTest: $passed assertions passed")
}
