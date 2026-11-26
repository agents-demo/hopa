package com.hopa.mmbert

import android.content.Context
import java.io.File

/**
 * Where the ranker weights live.
 *
 * The model is not in the APK: it is 140M parameters and belongs in the same
 * app-storage area as the other model files. The release asset is pinned by
 * SHA-256; a changed or truncated file never becomes the model.
 */
object MmBertModel {
    const val FILE = "mmbert_ui_scorer_fp32.onnx"

    /** Filled from the exported file; see tools/mmbert/README.md. */
    const val URL =
        "https://github.com/agents-demo/hopa/releases/download/mmbert-2026-11-25/mmbert_ui_scorer_fp32.onnx"
    const val SHA256 = "5fa6a630cb1eda0480772b939069f5f3243b67ff10d4259468cc07af6394e4fe"
    const val BYTES = 563_174_061L

    fun directory(context: Context): File =
        File(context.getExternalFilesDir(null) ?: context.filesDir, "mmbert")

    fun file(context: Context): File = File(directory(context), FILE)
}
