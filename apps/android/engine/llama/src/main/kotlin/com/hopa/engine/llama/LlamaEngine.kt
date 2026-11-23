package com.hopa.engine.llama

import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.inference.local.LocalEngine
import com.hopa.inference.local.ModelNotLoaded
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * llama.cpp behind JNI.
 *
 * Everything heavy happens off the main thread: loading a 640 MB file and every
 * token of generation take seconds, and doing that on the UI thread is exactly
 * the ANR the first phone build showed. [complete] therefore switches to the
 * default pool, where a blocked thread is harmless.
 *
 * One generation at a time: the native session has one context, so a chat turn
 * and a background run would otherwise decode into the same memory. [cancel]
 * is outside the lock on purpose: the stop button must reach a running decode.
 */
class LlamaEngine(
    private val pathProvider: () -> String?,
    private val contextTokens: Int = 4_096,
    private val threads: Int = Runtime.getRuntime().availableProcessors().coerceIn(2, 6),
    private val temperature: Float = 0.7f,
    private val topP: Float = 0.95f,
    private val topK: Int = 40,
    private val repeatPenalty: Float = 1.1f,
    /** Android thermal status; >= SEVERE means the phone needs a pause. */
    private val thermalStatus: () -> Int = { 0 },
) : LocalEngine {
    private val _tokens = MutableSharedFlow<String>(extraBufferCapacity = 128)

    /** Pieces as they are produced, for the chat to show while a turn runs. */
    val tokens: SharedFlow<String> = _tokens.asSharedFlow()

    private val lock = Mutex()
    private var handle: Long = 0L
    private var loadedPath: String = ""

    fun cancel() {
        if (libraryLoaded) nativeCancel()
    }

    fun release() {
        if (handle != 0L) {
            nativeFree(handle)
            handle = 0L
            loadedPath = ""
        }
    }

    private fun ensureLoaded(path: String): Boolean {
        if (handle != 0L && loadedPath == path) return true
        release()
        if (!libraryLoaded) return false
        handle = nativeLoad(path, contextTokens, threads)
        if (handle == 0L) return false
        loadedPath = path
        return true
    }

    override suspend fun complete(request: ModelRequest, grammar: String): ModelReply =
        withContext(Dispatchers.Default) {
            lock.withLock {
                if (thermalStatus() >= android.os.PowerManager.THERMAL_STATUS_SEVERE) {
                    throw ModelNotLoaded(
                        "The phone is too hot to run a model. Let it cool down, then try again.",
                    )
                }
                val path = pathProvider() ?: throw ModelNotLoaded(
                    "No on-device model is installed. Import a model file in Settings first.",
                )
                validate(path)?.let { reason -> throw ModelNotLoaded(reason) }
                if (!ensureLoaded(path)) {
                    throw ModelNotLoaded(
                        "This model could not be loaded: the file is damaged or its architecture " +
                            "is not supported by this build. Download it again from Settings.",
                    )
                }
                val prompt = promptFor(request)
                // A phone CPU writes a few tokens a second; a longer answer is a
                // different feature, not a longer wait.
                val cap = minOf(request.maxTokens, ON_DEVICE_MAX_TOKENS)
                val text = nativeCompleteStream(
                    handle = handle,
                    prompt = prompt,
                    maxTokens = cap,
                    grammar = grammar,
                    temperature = temperature,
                    topP = topP,
                    topK = topK,
                    repeatPenalty = repeatPenalty,
                ) { piece ->
                    _tokens.tryEmit(piece)
                }
                ModelReply(text = text)
            }
        }

    /**
     * A cheap refusal before the loader sees the file: a missing, tiny or
     * non-GGUF file becomes a named error instead of an abort inside llama.cpp.
     */
    private fun validate(path: String): String? {
        val file = java.io.File(path)
        if (!file.isFile) {
            return "The model file is missing. Download it again from Settings."
        }
        if (file.length() < MIN_MODEL_BYTES) {
            return "The model file is incomplete. Download it again from Settings."
        }
        val magic = ByteArray(4)
        val read = runCatching {
            file.inputStream().use { input -> input.read(magic) }
        }.getOrDefault(0)
        if (read != magic.size || String(magic, Charsets.US_ASCII) != "GGUF") {
            return "This file is not a GGUF model. Choose a .gguf file."
        }
        return null
    }

    /**
     * The exact chat format the model was trained on, read from its GGUF
     * metadata. A model without template metadata gets a plain transcript that
     * ends with the assistant marker, never an unterminated user turn.
     */
    private fun promptFor(request: ModelRequest): String {
        if (request.messages.isEmpty()) {
            return ""
        }
        val roles = request.messages.map { it.role }.toTypedArray()
        val contents = request.messages.map { it.content }.toTypedArray()
        val templated = runCatching { nativeApplyTemplate(handle, roles, contents) }
            .getOrDefault("")
        if (templated.isNotBlank()) {
            return templated
        }
        return request.messages.joinToString("\n\n") { "${it.role}: ${it.content}" } +
            "\n\nassistant:"
    }

    private external fun nativeLoad(path: String, contextTokens: Int, threads: Int): Long

    private external fun nativeFree(handle: Long)

    private external fun nativeCancel()

    private external fun nativeApplyTemplate(
        handle: Long,
        roles: Array<String>,
        contents: Array<String>,
    ): String

    private external fun nativeCompleteStream(
        handle: Long,
        prompt: String,
        maxTokens: Int,
        grammar: String,
        temperature: Float,
        topP: Float,
        topK: Int,
        repeatPenalty: Float,
        sink: TokenSink,
    ): String

    private companion object {
        const val ON_DEVICE_MAX_TOKENS = 160

        /** Smaller than this cannot be a real GGUF with weights. */
        const val MIN_MODEL_BYTES = 1L * 1024 * 1024

        val libraryLoaded: Boolean = runCatching {
            System.loadLibrary("hopa_llama")
        }.isSuccess
    }
}
