package com.hopa.contracts.model

/**
 * Scores candidate next actions against one screen.
 *
 * The implementation is a text cross-encoder: it receives the goal, the screen
 * summary and one string per candidate, and returns one logit per candidate.
 * It does not pick a winner and it does not act; the caller compares the scores.
 *
 * The interface lives here so the loop can depend on a tree ranker without
 * knowing whether it runs on ONNX Runtime or llama.cpp, and so a client without
 * a ranker passes `null` instead of a stub.
 *
 * There is no history parameter: the checkpoint this build ships was trained on
 * a goal and one screen only. A future checkpoint with action history needs a
 * new method, not a silently ignored argument.
 */
fun interface ActionScorer {
    fun score(goal: String, screen: String, candidates: List<String>): FloatArray
}
