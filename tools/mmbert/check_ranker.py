"""Compare the FP32 export, the INT8 export and PyTorch on realistic screens.

No gold labels: this checks that quantization keeps the ranking the FP32 model
produces, and measures the relative latency on this machine.
"""
import os
import time

import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer

HF = "sef1/android-ui-action-scorer-mmbert-small"
HERE = os.path.dirname(os.path.abspath(__file__))
FP32 = os.path.join(HERE, "out", "mmbert_ui_scorer_fp32.onnx")
INT8 = os.path.join(HERE, "out", "mmbert_ui_scorer_int8.onnx")

SCREENS = [
    (
        "Open Wi-Fi settings",
        "Network & internet | Battery | Display | Sound | Storage | Privacy",
        ["click Network & internet", "click Battery", "click Display", "click Sound",
         "click Storage", "click Privacy", "navigate back", "navigate home"],
    ),
    (
        "Turn on Bluetooth",
        "Connected devices | Bluetooth | Pair new device | Connection preferences",
        ["click Connected devices", "click Bluetooth", "click Pair new device",
         "click Connection preferences", "navigate back", "navigate home"],
    ),
    (
        "Set an alarm for 7 am",
        "Clock | Alarm | Timer | Stopwatch | Bedtime",
        ["click Clock", "click Alarm", "click Timer", "click Stopwatch", "click Bedtime",
         "navigate back", "navigate home"],
    ),
    (
        "Send a message to Liat that I will be late",
        "Messages | Liat | New conversation | Search | Send",
        ["click Messages", "click Liat", "click New conversation", "click Search",
         "type Search: I will be late", "click Send", "navigate back"],
    ),
    (
        "Open the camera and take a photo",
        "Camera | Photo | Video | Portrait | Settings | Shutter",
        ["click Camera", "click Photo", "click Video", "click Portrait",
         "click Shutter", "click Settings", "navigate back"],
    ),
    (
        "Check today's battery usage",
        "Battery | Battery saver | Usage since last full charge | Screen | Apps",
        ["click Battery", "click Battery saver", "click Usage since last full charge",
         "click Screen", "click Apps", "navigate back", "navigate home"],
    ),
    (
        "Install an app from the store",
        "Play Store | Search | Games | Apps | Books | Install",
        ["click Play Store", "click Search", "click Games", "click Apps", "click Books",
         "click Install", "navigate back"],
    ),
    (
        "Open the calculator and compute 12 times 8",
        "Calculator | 1 | 2 | 8 | plus | times | equals",
        ["click Calculator", "click 1", "click 2", "click 8", "click times",
         "click equals", "navigate back"],
    ),
]


def pair(goal: str, screen: str) -> str:
    return f"Goal: {goal} | Screen: {screen}"


def score(session: ort.InferenceSession, tok, text_a, candidates):
    batch = tok([text_a] * len(candidates), candidates, padding=True,
                truncation=True, max_length=256, return_tensors="np")
    out = session.run(None, {
        "input_ids": batch["input_ids"].astype(np.int64),
        "attention_mask": batch["attention_mask"].astype(np.int64),
    })[0]
    return out.reshape(-1)


def main():
    tok = AutoTokenizer.from_pretrained(HF)
    fp32 = ort.InferenceSession(FP32, providers=["CPUExecutionProvider"])
    int8 = ort.InferenceSession(INT8, providers=["CPUExecutionProvider"])

    agree = 0
    worst = 0.0
    for goal, screen, candidates in SCREENS:
        a = score(fp32, tok, pair(goal, screen), candidates)
        b = score(int8, tok, pair(goal, screen), candidates)
        top_a = int(np.argmax(a))
        top_b = int(np.argmax(b))
        same = top_a == top_b
        agree += int(same)
        # rank correlation of the candidate order
        order_a = np.argsort(-a)
        order_b = np.argsort(-b)
        overlap = len(set(order_a[:3]) & set(order_b[:3])) / 3
        worst = min(worst, overlap) if worst else overlap
        print(f"{'OK ' if same else 'DIFF'} {goal!r}: fp32={candidates[top_a]!r} "
              f"int8={candidates[top_b]!r} top3_overlap={overlap:.2f}")
        if not same:
            print("  fp32", np.round(a, 3))
            print("  int8", np.round(b, 3))
    print(f"top-1 agreement {agree}/{len(SCREENS)}, worst top-3 overlap {worst:.2f}")

    for name, session in (("fp32", fp32), ("int8", int8)):
        goal, screen, candidates = SCREENS[0]
        text = pair(goal, screen)
        for _ in range(3):
            score(session, tok, text, candidates)
        start = time.perf_counter()
        for _ in range(20):
            score(session, tok, text, candidates)
        print(f"{name}: {(time.perf_counter() - start) / 20 * 1000:.1f} ms per screen "
              f"({len(candidates)} candidates) on this CPU")


if __name__ == "__main__":
    main()
