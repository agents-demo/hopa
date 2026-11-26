package com.hopa.mmbert

import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.util.zip.GZIPInputStream

/**
 * Ported from `agents-demo/mmbert` (DroidFlowBench), `MetaspaceBpeTokenizer.kt`.
 *
 * Pure Kotlin Metaspace + BPE tokenizer compatible with Hugging Face tokenizer.json (mmBERT / Gemma-2).
 */
class MetaspaceBpeTokenizer private constructor(
    private val vocab: Map<String, Int>,
    private val mergeRanks: Map<String, Int>,
    private val bosId: Long = 2L,
    private val eosId: Long = 1L,
    private val padId: Long = 0L,
    private val unkId: Int = 3
) {

    fun encode(text: String): IntArray {
        val cleaned = text.trim()
        if (cleaned.isEmpty()) return intArrayOf()

        // Normalizer: replace space with '▁'; PreTokenizer: Metaspace(prepend_scheme="always", split=true)
        val normalized = "▁" + cleaned.replace(' ', '▁')
        val chunks = splitMetaspace(normalized)

        val ids = ArrayList<Int>(chunks.size * 2)
        for (chunk in chunks) {
            val pieces = bpe(chunk)
            for (p in pieces) {
                ids.add(vocab[p] ?: unkId)
            }
        }
        return ids.toIntArray()
    }

    fun encodePairBatch(textA: String, candidatesB: List<String>, maxLength: Int = 256): EncodedPairBatch {
        val tokensA = encode(textA)
        val encodedPairs = ArrayList<LongArray>(candidatesB.size)
        var maxSeq = 0

        for (cand in candidatesB) {
            val tokensB = encode(cand)
            // Budget: <bos> + A + <eos> + B + <eos> <= maxLength
            val maxTokensTotal = (maxLength - 3).coerceAtLeast(16)
            var lenA = tokensA.size
            var lenB = tokensB.size
            if (lenA + lenB > maxTokensTotal) {
                val reserveB = lenB.coerceAtMost(maxTokensTotal / 3)
                lenA = (maxTokensTotal - reserveB).coerceAtLeast(1)
                lenB = (maxTokensTotal - lenA).coerceAtLeast(0)
            }

            val seq = LongArray(3 + lenA + lenB)
            var idx = 0
            seq[idx++] = bosId
            for (i in 0 until lenA) seq[idx++] = tokensA[i].toLong()
            seq[idx++] = eosId
            for (i in 0 until lenB) seq[idx++] = tokensB[i].toLong()
            seq[idx] = eosId

            encodedPairs.add(seq)
            if (seq.size > maxSeq) maxSeq = seq.size
        }

        val paddedLen = maxSeq.coerceIn(1, maxLength)
        val idsBatch = Array(candidatesB.size) { row ->
            val seq = encodedPairs[row]
            LongArray(paddedLen) { col -> if (col < seq.size) seq[col] else padId }
        }
        val maskBatch = Array(candidatesB.size) { row ->
            val seqLenRow = encodedPairs[row].size
            LongArray(paddedLen) { col -> if (col < seqLenRow) 1L else 0L }
        }

        return EncodedPairBatch(inputIds = idsBatch, attentionMask = maskBatch, seqLen = paddedLen)
    }

    private fun splitMetaspace(input: String): List<String> {
        val out = ArrayList<String>()
        var start = 0
        for (i in 1 until input.length) {
            if (input[i] == '▁') {
                if (i > start) {
                    out.add(input.substring(start, i))
                }
                start = i
            }
        }
        if (start < input.length) {
            out.add(input.substring(start))
        }
        return out
    }

    private fun bpe(token: String): List<String> {
        if (token.length <= 1) return listOf(token)
        var word = token.map { it.toString() }.toMutableList()

        while (word.size > 1) {
            var bestRank = Int.MAX_VALUE
            var bestIdx = -1
            for (i in 0 until word.size - 1) {
                val rank = mergeRanks["${word[i]}\u0000${word[i + 1]}"]
                if (rank != null && rank < bestRank) {
                    bestRank = rank
                    bestIdx = i
                }
            }
            if (bestIdx < 0) break

            val merged = word[bestIdx] + word[bestIdx + 1]
            val next = ArrayList<String>(word.size - 1)
            var i = 0
            while (i < word.size) {
                if (i == bestIdx) {
                    next.add(merged)
                    i += 2
                } else {
                    next.add(word[i])
                    i += 1
                }
            }
            word = next
        }
        return word
    }

    companion object {
        fun fromTokenizerJson(stream: InputStream, isGzipped: Boolean): MetaspaceBpeTokenizer {
            val actualStream = if (isGzipped) GZIPInputStream(stream, 64 * 1024) else stream
            val reader = BufferedReader(InputStreamReader(actualStream, Charsets.UTF_8), 64 * 1024)
            val vocabMap = HashMap<String, Int>(262144)
            val ranks = HashMap<String, Int>(262144)
            var foundModel = false
            var foundVocab = false

            reader.use { br ->
                val parser = StreamingTokenizerJsonParser(br)
                parser.expectChar('{')
                var firstTop = true
                while (true) {
                    val next = parser.peekNonWs()
                    if (next == '}'.code) {
                        parser.consume()
                        break
                    }
                    if (!firstTop) parser.expectChar(',')
                    firstTop = false
                    val topKey = parser.readString()
                    parser.expectChar(':')
                    when (topKey) {
                        "added_tokens" -> parser.readAddedTokens(vocabMap)
                        "model" -> {
                            foundModel = true
                            foundVocab = parser.readModelSection(vocabMap, ranks)
                        }
                        else -> parser.skipValue()
                    }
                }
            }

            if (!foundModel) error("Missing 'model' in tokenizer.json")
            if (!foundVocab) error("Missing 'vocab' in tokenizer.json")

            return MetaspaceBpeTokenizer(
                vocab = vocabMap,
                mergeRanks = ranks,
                bosId = (vocabMap["<bos>"] ?: 2).toLong(),
                eosId = (vocabMap["<eos>"] ?: 1).toLong(),
                padId = (vocabMap["<pad>"] ?: 0).toLong(),
                unkId = vocabMap["<unk>"] ?: 3
            )
        }
    }
}

/**
 * Zero-DOM streaming JSON pull-parser for Hugging Face tokenizer.json (~18 MB+),
 * keeping peak Android Dalvik heap tiny by populating vocab/merges directly.
 */
private class StreamingTokenizerJsonParser(private val reader: BufferedReader) {
    private var pushed: Int = -2 // -2 = empty, -1 = EOF, >=0 = char code
    private val strBuf = StringBuilder(128)

    private fun nextChar(): Int {
        if (pushed != -2) {
            val c = pushed
            pushed = -2
            return c
        }
        return reader.read()
    }

    private fun peekChar(): Int {
        if (pushed == -2) {
            pushed = reader.read()
        }
        return pushed
    }

    fun peekNonWs(): Int {
        while (true) {
            val c = peekChar()
            if (c < 0) return -1
            if (c != ' '.code && c != '\n'.code && c != '\r'.code && c != '\t'.code) return c
            nextChar()
        }
    }

    fun consume(): Int = nextChar()

    fun expectChar(expected: Char) {
        val c = peekNonWs()
        if (c != expected.code) {
            error("Expected '$expected' in tokenizer.json, got ${if (c < 0) "EOF" else c.toChar()}")
        }
        nextChar()
    }

    fun readString(): String {
        expectChar('"')
        strBuf.setLength(0)
        while (true) {
            val c = nextChar()
            if (c < 0) error("Unterminated JSON string")
            when (c) {
                '"'.code -> return strBuf.toString()
                '\\'.code -> {
                    val esc = nextChar()
                    if (esc < 0) error("Unterminated escape in JSON string")
                    when (esc) {
                        '"'.code -> strBuf.append('"')
                        '\\'.code -> strBuf.append('\\')
                        '/'.code -> strBuf.append('/')
                        'b'.code -> strBuf.append('\b')
                        'f'.code -> strBuf.append('\u000C')
                        'n'.code -> strBuf.append('\n')
                        'r'.code -> strBuf.append('\r')
                        't'.code -> strBuf.append('\t')
                        'u'.code -> {
                            var code = 0
                            for (k in 0 until 4) {
                                val h = nextChar()
                                val digit = when (h) {
                                    in '0'.code..'9'.code -> h - '0'.code
                                    in 'a'.code..'f'.code -> h - 'a'.code + 10
                                    in 'A'.code..'F'.code -> h - 'A'.code + 10
                                    else -> error("Invalid hex escape in JSON string")
                                }
                                code = (code shl 4) or digit
                            }
                            strBuf.append(code.toChar())
                        }
                        else -> strBuf.append(esc.toChar())
                    }
                }
                else -> strBuf.append(c.toChar())
            }
        }
    }

    private fun readInt(): Int {
        var c = peekNonWs()
        var neg = false
        if (c == '-'.code) {
            neg = true
            nextChar()
            c = peekChar()
        }
        var value = 0
        while (c in '0'.code..'9'.code) {
            value = value * 10 + (c - '0'.code)
            nextChar()
            c = peekChar()
        }
        return if (neg) -value else value
    }

    fun skipValue() {
        val c = peekNonWs()
        when (c) {
            '"'.code -> readString()
            '{'.code -> {
                nextChar()
                var first = true
                while (true) {
                    if (peekNonWs() == '}'.code) {
                        nextChar()
                        return
                    }
                    if (!first) expectChar(',')
                    first = false
                    readString()
                    expectChar(':')
                    skipValue()
                }
            }
            '['.code -> {
                nextChar()
                var first = true
                while (true) {
                    if (peekNonWs() == ']'.code) {
                        nextChar()
                        return
                    }
                    if (!first) expectChar(',')
                    first = false
                    skipValue()
                }
            }
            't'.code, 'f'.code, 'n'.code -> {
                while (true) {
                    val p = peekChar()
                    if (p in 'a'.code..'z'.code) nextChar() else break
                }
            }
            else -> {
                while (true) {
                    val p = peekChar()
                    if (p in '0'.code..'9'.code || p == '-'.code || p == '+'.code || p == '.'.code || p == 'e'.code || p == 'E'.code) {
                        nextChar()
                    } else {
                        break
                    }
                }
            }
        }
    }

    fun readAddedTokens(vocabMap: MutableMap<String, Int>) {
        if (peekNonWs() == 'n'.code) {
            skipValue()
            return
        }
        expectChar('[')
        var firstElem = true
        while (true) {
            if (peekNonWs() == ']'.code) {
                nextChar()
                return
            }
            if (!firstElem) expectChar(',')
            firstElem = false
            expectChar('{')
            var content: String? = null
            var id: Int? = null
            var firstField = true
            while (true) {
                if (peekNonWs() == '}'.code) {
                    nextChar()
                    break
                }
                if (!firstField) expectChar(',')
                firstField = false
                val k = readString()
                expectChar(':')
                when (k) {
                    "content" -> content = readString()
                    "id" -> id = readInt()
                    else -> skipValue()
                }
            }
            if (content != null && id != null) {
                vocabMap[content] = id
            }
        }
    }

    fun readModelSection(vocabMap: MutableMap<String, Int>, ranks: MutableMap<String, Int>): Boolean {
        expectChar('{')
        var foundVocab = false
        var first = true
        while (true) {
            if (peekNonWs() == '}'.code) {
                nextChar()
                return foundVocab
            }
            if (!first) expectChar(',')
            first = false
            val k = readString()
            expectChar(':')
            when (k) {
                "vocab" -> {
                    foundVocab = true
                    readVocabObject(vocabMap)
                }
                "merges" -> readMergesArray(ranks)
                else -> skipValue()
            }
        }
    }

    private fun readVocabObject(vocabMap: MutableMap<String, Int>) {
        expectChar('{')
        var first = true
        while (true) {
            if (peekNonWs() == '}'.code) {
                nextChar()
                return
            }
            if (!first) expectChar(',')
            first = false
            val token = readString()
            expectChar(':')
            val id = readInt()
            vocabMap[token] = id
        }
    }

    private fun readMergesArray(ranks: MutableMap<String, Int>) {
        if (peekNonWs() == 'n'.code) {
            skipValue()
            return
        }
        expectChar('[')
        var idx = 0
        var first = true
        while (true) {
            val next = peekNonWs()
            if (next == ']'.code) {
                nextChar()
                return
            }
            if (!first) expectChar(',')
            first = false
            when (peekNonWs()) {
                '"'.code -> {
                    val line = readString()
                    val sp = line.indexOf(' ')
                    if (sp > 0 && sp < line.length - 1) {
                        ranks["${line.substring(0, sp)}\u0000${line.substring(sp + 1)}"] = idx
                    }
                }
                '['.code -> {
                    nextChar()
                    val a = readString()
                    expectChar(',')
                    val b = readString()
                    while (peekNonWs() == ','.code) {
                        nextChar()
                        skipValue()
                    }
                    expectChar(']')
                    ranks["$a\u0000$b"] = idx
                }
                else -> skipValue()
            }
            idx++
        }
    }
}
