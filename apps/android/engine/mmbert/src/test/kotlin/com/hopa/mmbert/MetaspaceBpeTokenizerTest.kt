package com.hopa.mmbert

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class MetaspaceBpeTokenizerTest {

    @Test
    fun the_ids_match_the_hugging_face_tokenizer() {
        val tokenizer = tokenizer()

        assertArrayEquals(intArrayOf(5499, 15159, 20813), tokenizer.encode("click Button Settings"))
        assertArrayEquals(intArrayOf(31201, 1355), tokenizer.encode("navigate back"))
    }

    @Test
    fun a_pair_is_bos_a_eos_b_eos_and_padded() {
        val tokenizer = tokenizer()
        val batch = tokenizer.encodePairBatch(
            textA = "Goal: Open Settings | Screen: Search | Settings",
            candidatesB = listOf("click Search", "navigate back"),
            maxLength = 64,
        )

        assertEquals(2, batch.inputIds.size)
        assertEquals(2, batch.attentionMask.size)
        assertTrue(batch.seqLen in 1..64)
        for (row in batch.inputIds.indices) {
            val active = batch.attentionMask[row].count { it == 1L }
            assertEquals(2L, batch.inputIds[row].first())
            assertEquals(1L, batch.inputIds[row][active - 1])
            assertEquals(1L, batch.attentionMask[row].first())
            if (active < batch.seqLen) {
                assertEquals(0L, batch.attentionMask[row][active])
            }
            assertTrue(batch.inputIds[row].drop(active).all { it == 0L }, "padding must be <pad>")
        }
    }

    private fun tokenizer(): MetaspaceBpeTokenizer {
        val stream = javaClass.getResourceAsStream("/mmbert_tokenizer.json.gz")
            ?: error("the tokenizer asset is not on the test classpath")
        return stream.use { MetaspaceBpeTokenizer.fromTokenizerJson(it, isGzipped = true) }
    }
}
