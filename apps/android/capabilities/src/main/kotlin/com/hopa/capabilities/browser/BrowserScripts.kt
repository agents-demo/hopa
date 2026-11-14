package com.hopa.capabilities.browser

/** The JavaScript the Browser uses, and the text cap both sides agree on. */
object BrowserScripts {
    const val MAX_TEXT = 20_000

    const val READ = "document.body ? document.body.innerText : ''"

    fun click(selector: String): String =
        "(function(){var e=document.querySelector(${quoted(selector)});" +
            "if(!e){return 'missing';}e.click();return 'ok';})()"

    fun type(selector: String, text: String): String =
        "(function(){var e=document.querySelector(${quoted(selector)});" +
            "if(!e){return 'missing';}e.focus();e.value=${quoted(text)};" +
            "e.dispatchEvent(new Event('input',{bubbles:true}));" +
            "e.dispatchEvent(new Event('change',{bubbles:true}));return 'ok';})()"

    fun cap(text: String): String = text.take(MAX_TEXT)

    /** A JavaScript string literal; quotes, slashes and newlines are escaped. */
    fun quoted(value: String): String {
        val builder = StringBuilder(value.length + 2)
        builder.append('"')
        for (character in value) {
            when (character) {
                '\\' -> builder.append("\\\\")
                '"' -> builder.append("\\\"")
                '\n' -> builder.append("\\n")
                '\r' -> builder.append("\\r")
                '\t' -> builder.append("\\t")
                '\u2028' -> builder.append("\\u2028")
                '\u2029' -> builder.append("\\u2029")
                else -> builder.append(character)
            }
        }
        builder.append('"')
        return builder.toString()
    }
}
