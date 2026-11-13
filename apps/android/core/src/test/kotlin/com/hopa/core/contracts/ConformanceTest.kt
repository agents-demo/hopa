package com.hopa.core.contracts

import com.hopa.core.gate.ActionClassifier
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.core.json.HopaJson
import com.hopa.core.observation.ObservationHasher
import com.hopa.core.parser.DecisionParser
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class ConformanceTest {
    @Test
    fun every_fixture_matches_the_contract() {
        val document = resource("/fixtures/conformance.json")
        val cases = document["cases"]!!.jsonArray
        for (case in cases) {
            val item = case.jsonObject
            val name = item["name"]!!.jsonPrimitive.content
            val observation = HopaJson.element.decodeFromJsonElement(
                Observation.serializer(),
                item["observation"]!!,
            )
            val reply = item["modelReply"]!!.toString()
            val expect = item["expect"]!!.jsonObject
            val valid = expect["valid"]!!.jsonPrimitive.boolean
            val outcome = DecisionParser().parse(reply)
            if (!valid) {
                assertNotNull("$name should be invalid", outcome.error)
                continue
            }
            val action = outcome.decision?.action
            assertNotNull("$name should parse an action", action)
            action ?: continue
            assertEquals(
                "$name action kind",
                expect["actionKind"]!!.jsonPrimitive.content,
                action.kind,
            )
            val classification = ActionClassifier().classify(action, observation)
            assertEquals(
                "$name classification",
                expect["classification"]!!.jsonPrimitive.content,
                classification.name.lowercase(),
            )
            val needsApproval = ApprovalPolicy().requiresApproval(action, observation)
            assertEquals(
                "$name needsApproval",
                expect["needsApproval"]!!.jsonPrimitive.boolean,
                needsApproval,
            )
            assertEquals(
                "$name executed",
                expect["executed"]!!.jsonPrimitive.boolean,
                !needsApproval,
            )
        }
    }

    @Test
    fun the_observation_hash_vector_matches() {
        val document = resource("/fixtures/observation-hash.json")
        for (case in document["cases"]!!.jsonArray) {
            val item = case.jsonObject
            val observation = HopaJson.element.decodeFromJsonElement(
                Observation.serializer(),
                item["observation"]!!,
            )
            assertEquals(item["hash"]!!.jsonPrimitive.content, ObservationHasher.hash(observation))
        }
    }

    private fun resource(path: String) = HopaJson.element.parseToJsonElement(
        requireNotNull(javaClass.getResource(path)) { "missing $path" }.readText(),
    ).jsonObject
}
