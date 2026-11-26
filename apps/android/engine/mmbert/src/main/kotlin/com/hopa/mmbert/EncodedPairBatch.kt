package com.hopa.mmbert

/** One padded batch of mBERT pairs: `[bos] A [eos] B [eos]` per row. */
data class EncodedPairBatch(
    val inputIds: Array<LongArray>,
    val attentionMask: Array<LongArray>,
    val seqLen: Int,
)
