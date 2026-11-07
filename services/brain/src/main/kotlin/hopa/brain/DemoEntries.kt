package hopa.brain

/**
 * Demo knowledge for the reference brain and the contract tests.
 *
 * This is not the Mika knowledge corpus. It is a small, explicit set of
 * HarmonyOS system apps plus three web-capable apps.
 */
object DemoEntries {
    val all: List<KnowledgeEntry> = listOf(
        KnowledgeEntry(
            name = "settings",
            display = "Settings",
            aliases = listOf("设置"),
            packages = listOf("com.huawei.hmos.settings"),
            packageAliases = mapOf("settings" to "com.huawei.hmos.settings"),
        ),
        KnowledgeEntry(
            name = "clock",
            display = "Clock",
            aliases = listOf("闹钟", "时钟", "alarm"),
            packages = listOf("com.huawei.hmos.clock"),
        ),
        KnowledgeEntry(
            name = "calendar",
            display = "Calendar",
            aliases = listOf("日历", "日程"),
            packages = listOf("com.huawei.hmos.calendar"),
        ),
        KnowledgeEntry(
            name = "notes",
            display = "Notes",
            aliases = listOf("notes", "备忘录", "笔记"),
            packages = listOf("com.huawei.hmos.notepad"),
        ),
        KnowledgeEntry(
            name = "notepad",
            display = "Notepad",
            aliases = listOf("notes", "notepad"),
            packages = listOf("com.huawei.hmos.notepad.pro"),
        ),
        KnowledgeEntry(
            name = "contacts",
            display = "Contacts",
            aliases = listOf("联系人", "通讯录"),
            packages = listOf("com.ohos.contacts"),
        ),
        KnowledgeEntry(
            name = "files",
            display = "Files",
            aliases = listOf("文件", "文件管理"),
            packages = listOf("com.huawei.hmos.files"),
        ),
        KnowledgeEntry(
            name = "camera",
            display = "Camera",
            aliases = listOf("相机", "拍照"),
            packages = listOf("com.huawei.hmos.camera"),
        ),
        KnowledgeEntry(
            name = "gallery",
            display = "Gallery",
            aliases = listOf("图库", "相册"),
            packages = listOf("com.huawei.hmos.photos"),
        ),
        KnowledgeEntry(
            name = "browser",
            display = "Browser",
            aliases = listOf("浏览器"),
            packages = listOf("com.huawei.hmos.browser"),
            domains = listOf("huawei.com"),
            service = "browser",
        ),
        KnowledgeEntry(
            name = "appgallery",
            display = "AppGallery",
            aliases = listOf("应用市场", "app store"),
            packages = listOf("com.huawei.hmsapp.appgallery"),
        ),
        KnowledgeEntry(
            name = "petal-maps",
            display = "Petal Maps",
            aliases = listOf("地图", "petal maps"),
            packages = listOf("com.huawei.hmos.petalmaps"),
            domains = listOf("petalmaps.com"),
            service = "petal-maps",
        ),
        KnowledgeEntry(
            name = "music",
            display = "Music",
            aliases = listOf("音乐", "播放器"),
            packages = listOf("com.huawei.hmos.music"),
        ),
        KnowledgeEntry(
            name = "xiaohongshu",
            display = "Xiaohongshu",
            aliases = listOf("小红书", "xhs"),
            packages = listOf("com.xingin.xhs"),
            domains = listOf("xiaohongshu.com"),
            service = "xiaohongshu",
        ),
        KnowledgeEntry(
            name = "wechat",
            display = "WeChat",
            aliases = listOf("微信", "weixin"),
            packages = listOf("com.tencent.wechat"),
            domains = listOf("weixin.qq.com"),
            service = "wechat",
        ),
        KnowledgeEntry(
            name = "amazon",
            display = "Amazon",
            aliases = listOf("亚马逊"),
            domains = listOf("amazon.com"),
            service = "amazon",
        ),
    )
}
