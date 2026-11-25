package com.hopa.mmbert

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.hopa.contracts.model.ActionScorer
import java.io.Closeable
import java.io.File
import java.nio.LongBuffer

/**
 * The ONNX Runtime half of the tree ranker.
 *
 * One session, one tokenizer, one call per screen: the same pair format the
 * AndroidControl fine-tune saw (`Goal: ... | Screen: ...` against one candidate
 * action), padded to 256 tokens and scored as a batch. No pixels, no history.
 */
class MmBertScorer internal constructor(
    private val session: OrtSession,
    private val tokenizer: MetaspaceBpeTokenizer,
) : ActionScorer, Closeable {

    override fun score(goal: String, screen: String, candidates: List<String>): FloatArray {
        require(candidates.isNotEmpty()) { "a score needs at least one candidate" }
        val textA = "Goal: $goal | Screen: $screen"
        val batch = tokenizer.encodePairBatch(textA, candidates, MAX_TOKENS)
        val rows = candidates.size
        val cols = batch.seqLen
        val ids = LongBuffer.allocate(rows * cols)
        val mask = LongBuffer.allocate(rows * cols)
        for (row in 0 until rows) {
            ids.put(batch.inputIds[row])
            mask.put(batch.attentionMask[row])
        }
        ids.rewind()
        mask.rewind()

        val shape = longArrayOf(rows.toLong(), cols.toLong())
        val scores = FloatArray(rows)
        OnnxTensor.createTensor(environment, ids, shape).use { idsTensor ->
            OnnxTensor.createTensor(environment, mask, shape).use { maskTensor ->
                session.run(mapOf("input_ids" to idsTensor, "attention_mask" to maskTensor)).use { result ->
                    when (val out = result[0].value) {
                        is Array<*> -> for (row in 0 until rows) {
                            scores[row] = (out.getOrNull(row) as? FloatArray)?.firstOrNull()
                                ?: Float.NEGATIVE_INFINITY
                        }
                        is FloatArray -> for (row in 0 until minOf(rows, out.size)) {
                            scores[row] = out[row]
                        }
                        else -> error("unexpected logits type: ${out?.javaClass}")
                    }
                }
            }
        }
        return scores
    }

    override fun close() {
        session.close()
    }

    companion object {
        private const val MAX_TOKENS = 256

        /** The environment is process-wide; only the session is per loader. */
        private val environment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

        fun open(context: Context, model: File): MmBertScorer {
            require(model.isFile) { "no ranker model at ${model.absolutePath}" }
            val options = OrtSession.SessionOptions().apply {
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                setIntraOpNumThreads(
                    Runtime.getRuntime().availableProcessors().coerceIn(1, 4),
                )
                setInterOpNumThreads(1)
            }
            val session = environment.createSession(model.absolutePath, options)
            return MmBertScorer(session, tokenizer(context))
        }

        private fun tokenizer(context: Context): MetaspaceBpeTokenizer =
            MmBertTokenizerAsset.get { context.assets.open("mmbert_tokenizer.json.gz") }
    }
}
