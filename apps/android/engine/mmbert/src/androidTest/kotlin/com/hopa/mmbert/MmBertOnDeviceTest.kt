package com.hopa.mmbert

import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The only test that runs the real ONNX session on a phone.
 *
 * It needs the pinned model in the app's external files directory; without it
 * the test is skipped, so a clean checkout still has a green unit-test run.
 */
@RunWith(AndroidJUnit4::class)
class MmBertOnDeviceTest {

    @Test
    fun scores_one_screen_and_reports_latency() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val model = MmBertModel.file(context)
        assumeTrue("no ranker model at ${model.absolutePath}", model.isFile)

        val candidates = listOf(
            "click Search",
            "click Network & internet",
            "click Battery",
            "click Display",
            "navigate back",
            "navigate home",
        )
        MmBertScorer.open(context, model).use { scorer ->
            // Warm-up: the first call loads tokenizer pages and ORT kernels.
            scorer.score("Open Wi-Fi settings", "Search | Network & internet | Battery | Display", candidates)
            val start = SystemClock.elapsedRealtime()
            var scores = FloatArray(0)
            repeat(3) {
                scores = scorer.score(
                    "Open Wi-Fi settings",
                    "Search | Network & internet | Battery | Display",
                    candidates,
                )
            }
            val millis = (SystemClock.elapsedRealtime() - start) / 3.0
            Log.i("MmBertOnDevice", "scores=${scores.toList()} avg=${millis}ms")
            assertEquals(candidates.size, scores.size)
            assertTrue("scores must be finite", scores.all { it.isFinite() })
            val best = scores.indices.maxBy { scores[it] }
            assertTrue("the winner must be a real candidate", best in candidates.indices)
        }
    }
}
