package com.hopa.engine.llama

/** Called by the native decoder for every piece it produces. */
fun interface TokenSink {
    fun onToken(text: String)
}
