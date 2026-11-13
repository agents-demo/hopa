package com.hopa.core.parser

object BalancedObjectScanner {
    fun scan(text: String): List<String> {
        val found = mutableListOf<String>()
        var depth = 0
        var start = -1
        var inString = false
        var escaped = false
        var index = 0
        while (index < text.length) {
            val char = text[index]
            if (inString) {
                when {
                    escaped -> escaped = false
                    char == '\\' -> escaped = true
                    char == '"' -> inString = false
                }
            } else {
                when (char) {
                    '"' -> inString = true
                    '{' -> {
                        if (depth == 0) {
                            start = index
                        }
                        depth += 1
                    }

                    '}' -> if (depth > 0) {
                        depth -= 1
                        if (depth == 0 && start >= 0) {
                            found += text.substring(start, index + 1)
                            start = -1
                        }
                    }
                }
            }
            index += 1
        }
        return found
    }
}
