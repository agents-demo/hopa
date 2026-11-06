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
        name: documents
        display: Documents
        description: Read and summarize a PDF
        terms: [PDF, document, 文档]
        apps: []
        sites: []
        ---
        # Documents

        Extract the text, then summarize it.
    """.trimIndent()

    val skill = SkillLoader.parse(sample)
    check(skill.name == "documents", "name")
    check(skill.display == "Documents", "display")
    check(skill.description.contains("PDF"), "description")
    check(skill.terms.contains("文档"), "terms")
    check(skill.apps.isEmpty(), "apps")

    var missing = false
    try {
        SkillLoader.parse("---\nname: x\ndisplay: X\n---\n")
    } catch (error: SkillFormatException) {
        missing = true
    }
    check(missing, "missing description is rejected")

    val directory = if (args.isNotEmpty()) {
        Path.of(args[0])
    } else {
        Path.of("brain/knowledge/skills")
    }
    val loaded = SkillLoader.load(directory)
    check(loaded.size == 6, "6 skill files")
    check(loaded.all { it.description.isNotEmpty() }, "all have descriptions")
    check(loaded.any { it.name == "documents" }, "documents present")
    check(loaded.any { it.name == "info-research" }, "info-research present")
    check(loaded.any { it.name == "messaging" }, "messaging present")

    println("SkillLoaderTest: $passed assertions passed")
}
