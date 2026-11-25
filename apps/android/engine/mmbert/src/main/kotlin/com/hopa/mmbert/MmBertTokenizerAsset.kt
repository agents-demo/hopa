package com.hopa.mmbert

import java.io.InputStream

/**
 * The tokenizer is a ~5 MB gzipped vocab and merge table; parsing it is the
 * slowest part of opening the ranker, so one copy is kept for the process.
 */
internal object MmBertTokenizerAsset {

    @Volatile
    private var cached: MetaspaceBpeTokenizer? = null

    fun get(open: () -> InputStream): MetaspaceBpeTokenizer {
        cached?.let { return it }
        return synchronized(this) {
            cached ?: open().use { stream ->
                MetaspaceBpeTokenizer.fromTokenizerJson(stream, isGzipped = true)
            }.also { cached = it }
        }
    }
}
