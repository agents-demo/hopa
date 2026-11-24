package com.hopa.sidecar.startup

import java.nio.file.Path

/** The `--turn` CLI. Unknown options fail closed instead of being ignored. */
internal data class CliOptions(
    val turn: String? = null,
    val dataDir: Path? = null,
    val conversationId: String? = null,
    val pairBackend: String? = null,
    val help: Boolean = false,
    val version: Boolean = false,
) {
    companion object {
        fun parse(args: Array<String>): CliOptions {
            var turn: String? = null
            var dataDir: Path? = null
            var conversationId: String? = null
            var pairBackend: String? = null
            var help = false
            var version = false
            var index = 0
            while (index < args.size) {
                val arg = args[index]
                when {
                    arg == "--turn" -> {
                        turn = args.getOrNull(++index)
                            ?: throw IllegalArgumentException("--turn needs a goal")
                    }

                    arg.startsWith("--turn=") -> turn = arg.removePrefix("--turn=")

                    arg == "--data-dir" -> {
                        dataDir = Path.of(
                            args.getOrNull(++index)
                                ?: throw IllegalArgumentException("--data-dir needs a path"),
                        )
                    }

                    arg.startsWith("--data-dir=") -> dataDir = Path.of(arg.removePrefix("--data-dir="))

                    arg == "--conversation" -> {
                        conversationId = args.getOrNull(++index)
                            ?: throw IllegalArgumentException("--conversation needs an id")
                    }

                    arg.startsWith("--conversation=") ->
                        conversationId = arg.removePrefix("--conversation=")

                    arg == "--pair-backend" -> {
                        pairBackend = args.getOrNull(++index)
                            ?.takeIf { it.isNotBlank() && !it.startsWith("--") }
                            ?: throw IllegalArgumentException("--pair-backend needs a URL")
                    }

                    arg.startsWith("--pair-backend=") ->
                        pairBackend = arg.removePrefix("--pair-backend=").takeIf { it.isNotBlank() }

                    arg == "--help" || arg == "-h" -> help = true

                    arg == "--version" -> version = true

                    else -> throw IllegalArgumentException("unknown option: $arg")
                }
                index += 1
            }
            return CliOptions(
                turn = turn,
                dataDir = dataDir,
                conversationId = conversationId,
                pairBackend = pairBackend,
                help = help,
                version = version,
            )
        }
    }
}
