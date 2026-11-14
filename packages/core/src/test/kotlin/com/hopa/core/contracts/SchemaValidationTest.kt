package com.hopa.core.contracts

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.ObjectNode
import com.hopa.core.json.HopaJson
import com.hopa.core.records.RunChain
import com.hopa.core.records.RunRecordDraft
import com.networknt.schema.JsonSchema
import com.networknt.schema.JsonSchemaFactory
import com.networknt.schema.SpecVersion
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Schema-only checks. The two fixtures that need the semantic gate
 * (`doneWithAction`, `needUser` without options) pass the schema and are
 * rejected by `DecisionRules`; the test says so instead of pretending the
 * schema covers them.
 */
class SchemaValidationTest {
    private val mapper = ObjectMapper()
    private val factory = JsonSchemaFactory.getInstance(SpecVersion.VersionFlag.V202012)

    @Test
    fun every_fixture_observation_matches_the_schema() {
        val schema = schema("observation.schema.json")
        for (file in listOf("observation-hash.json", "conformance.json")) {
            for (case in cases(file)) {
                val messages = schema.validate(case["observation"])
                assertTrue("${case["name"]!!.asText()}: $messages", messages.isEmpty())
            }
        }
    }

    @Test
    fun fixture_decisions_match_the_schema_except_the_semantic_rejections() {
        val schema = schema("decision.schema.json")
        val semantic = setOf("done-with-an-action-is-rejected", "a-question-needs-options")
        for (case in cases("conformance.json")) {
            val name = case["name"]!!.asText()
            val messages = schema.validate(case["modelReply"])
            if (name == "unknown-action-kind-is-rejected") {
                assertFalse("$name must fail at the action enum", messages.isEmpty())
            } else if (name in semantic) {
                assertTrue("$name is rejected by DecisionRules, not the schema", messages.isEmpty())
            } else {
                assertTrue("$name: $messages", messages.isEmpty())
            }
        }
    }

    @Test
    fun a_sealed_record_matches_the_schema_with_an_explicit_null_approval() {
        val record = RunChain.seal(
            RunRecordDraft(
                runId = "run-1",
                step = 0,
                traceId = "trace-1",
                action = Action(kind = "ui.observe"),
                classification = "read",
                approved = null,
                observationHash = "sha256:" + "0".repeat(64),
                verified = true,
                executed = true,
            ),
            RunChain.SEED,
        )
        val node = mapper.readTree(HopaJson.element.encodeToString(RunRecord.serializer(), record))
        val messages = schema("run-record.schema.json").validate(node)
        assertTrue("$messages", messages.isEmpty())
        assertTrue("approved must be present", node.has("approved"))
        assertTrue("approved must be null, not omitted", node["approved"]!!.isNull)
    }

    private fun cases(file: String): List<JsonNode> {
        val document = mapper.readTree(resource("/fixtures/$file"))
        return document["cases"].toList()
    }

    private fun schema(name: String): JsonSchema = factory.getSchema(inline(read(name)))

    private fun read(name: String): JsonNode =
        mapper.readTree(resource("/schemas/$name"))

    private fun resource(path: String): String =
        requireNotNull(javaClass.getResource(path)) { "missing $path" }.readText()

    /** Inline the sibling schema files so validation never touches the network. */
    private fun inline(node: JsonNode): JsonNode = when {
        node.isObject -> {
            val ref = node.get("\$ref")?.takeIf { it.isTextual }?.asText()
            if (ref != null && ref.endsWith(".schema.json")) {
                inline(read(ref))
            } else {
                val copy = node.deepCopy<ObjectNode>()
                val entries = copy.fields().asSequence().toList()
                for ((key, value) in entries) {
                    copy.set<JsonNode>(key, inline(value))
                }
                copy
            }
        }

        node.isArray -> {
            val copy = mapper.createArrayNode()
            node.forEach { copy.add(inline(it)) }
            copy
        }

        else -> node
    }
}
