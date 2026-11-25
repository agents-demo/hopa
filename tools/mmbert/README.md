# mmBERT tree ranker

The optional on-device rung between the graph and a language model: it reads the
accessibility tree, scores the candidate actions for the current screen, and
picks one if the winner is clear.

It is a **cross-encoder ranker**, not a planner. It cannot open an app it cannot
see, it cannot answer a question, and it does not decide that a goal is done.
`TreeRankerDecisionPolicy` therefore returns `NoPath` for everything except one
tap, one scroll, back or home, and the turn falls through to the model.

## Provenance

- Demo/harness: `agents-demo/mmbert` (DroidFlowBench), built for HOPA.
- Checkpoint: [`sef1/android-ui-action-scorer-mmbert-small`](https://huggingface.co/sef1/android-ui-action-scorer-mmbert-small),
  a ModernBERT-small sequence classifier (~140M parameters), text only.
- Training data: AndroidControl, English, with human low-level step
  instructions. The model card lists its benchmark limits; read them before
  treating a score as an accuracy claim.

## Export

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\pip install torch --index-url https://download.pytorch.org/whl/cpu
.\.venv\Scripts\pip install transformers onnx onnxruntime huggingface_hub numpy
.\.venv\Scripts\python tools\mmbert\export_onnx.py
```

The script writes `tools/mmbert/out/mmbert_ui_scorer_fp32.onnx` (563,174,061
bytes, SHA-256 `5fa6a630cb1eda0480772b939069f5f3243b67ff10d4259468cc07af6394e4fe`)
and a dynamic INT8 copy.

### Why FP32

Dynamic INT8 (default, per-channel, reduce-range, and MatMul-only) changed the
top-1 action on 5–6 of 8 representative screens when compared with FP32, because
the logits of the correct and wrong candidate are often within 0.01. The model
is too close to ties for weight-only quantization without calibration. FP16
export fails in ONNX Runtime CPU on `LayerNormalization` (mixed float/float16).

An INT8 file can come back once there is a real calibration set and an Android
eval harness; until then the pinned FP32 file is the honest choice. It is large
(≈537 MiB) and needs roughly 1 GB of free memory while loaded.

## Release asset

The app downloads the pinned file from:

```
https://github.com/agents-demo/hopa/releases/download/mmbert-2026-11-25/mmbert_ui_scorer_fp32.onnx
```

The URL, size and checksum live in
`apps/android/engine/mmbert/src/main/kotlin/com/hopa/mmbert/MmBertStore.kt`.
Update all three together.

## On a phone without the download

Debug builds can be side-loaded into the app's external files directory:

```powershell
adb push mmbert_ui_scorer_fp32.onnx /sdcard/Android/data/com.hopa.android/files/mmbert/
```

Release builds must use the in-app download in **How HOPA acts → Steps → Tree
ranker**.

## How it is wired

| Piece | Path |
|---|---|
| ONNX session + tokenizer | `apps/android/engine/mmbert/` |
| Candidate builder | `core/agent/.../decision/tree/TreeCandidates.kt` |
| Rung | `core/agent/.../decision/tree/TreeRankerDecisionPolicy.kt` |
| Order | `TurnRunner`: recipe → graph → command → **tree** → model → API |
| Toggle + download | How HOPA acts → Steps → Tree ranker |

The policy runs for at most three steps of a turn, then hands over. It never
picks a candidate whose words name a sending, deleting, payment or confirmation
action. A `task complete done` winner is `NoPath`: only the model or a verified
checkpoint may end the turn.

## Quick check on a desktop

`tools/mmbert/check_ranker.py` runs eight representative screens through the
FP32 and INT8 files, prints the winner and the top-3 overlap, and reports the
latency on this machine. It is a sanity check, not an evaluation: it has no gold
labels.

## What is still missing

- A gold eval set (the upstream `eval_2k.jsonl` is not in the demo repository).
- Candidate recall: the upstream evaluation guaranteed the correct candidate was
  in the list, so the ranking accuracy is not end-to-end task success.
- A phone benchmark on a release build and low-RAM devices.
