import json
from pathlib import Path
import torch
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import onnxruntime as ort
from onnxruntime.quantization import quantize_dynamic, QuantType
import numpy as np

REPO = "sef1/android-ui-action-scorer-mmbert-small"
REV = "a55441949ca9ad8567417de6a3bb038f64d83a0d"
OUT_DIR = Path(__file__).resolve().parent / "out"
OUT_DIR.mkdir(parents=True, exist_ok=True)

local_repo = Path(snapshot_download(repo_id=REPO, revision=REV))
print("Downloaded repo to:", local_repo)

tok_json = json.loads((local_repo / "tokenizer.json").read_text(encoding="utf-8"))
print("Tokenizer model type:", tok_json.get("model", {}).get("type"))
print("Normalizer:", json.dumps(tok_json.get("normalizer"), indent=2)[:400])
print("PreTokenizer:", json.dumps(tok_json.get("pre_tokenizer"), indent=2)[:400])
print("PostProcessor:", json.dumps(tok_json.get("post_processor"), indent=2)[:400])

tokenizer = AutoTokenizer.from_pretrained(str(local_repo))
model = AutoModelForSequenceClassification.from_pretrained(str(local_repo), torch_dtype=torch.float32)
model.eval()

# Test sample pair
sample = tokenizer(
    "Goal: open SMS app, Send SMS to Liat that I will be late in 15 min | Screen: Phone, Messages, Maps, Settings",
    "click Button Messages",
    padding="max_length",
    truncation=True,
    max_length=256,
    return_tensors="pt"
)

with torch.no_grad():
    pt_logits = model(input_ids=sample["input_ids"], attention_mask=sample["attention_mask"]).logits.numpy()
print("PyTorch FP32 logit:", pt_logits)

fp32_onnx = OUT_DIR / "mmbert_ui_scorer_fp32.onnx"
int8_onnx = OUT_DIR / "mmbert_ui_scorer_int8.onnx"

class OnnxWrapper(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, input_ids, attention_mask):
        return self.m(input_ids=input_ids, attention_mask=attention_mask).logits

wrapper = OnnxWrapper(model)
torch.onnx.export(
    wrapper,
    (sample["input_ids"], sample["attention_mask"]),
    str(fp32_onnx),
    input_names=["input_ids", "attention_mask"],
    output_names=["logits"],
    dynamic_axes={
        "input_ids": {0: "batch", 1: "seq"},
        "attention_mask": {0: "batch", 1: "seq"},
        "logits": {0: "batch"},
    },
    opset_version=17,
    dynamo=False,
)
print("Exported FP32 ONNX:", fp32_onnx, fp32_onnx.stat().st_size)

quantize_dynamic(
    model_input=str(fp32_onnx),
    model_output=str(int8_onnx),
    weight_type=QuantType.QInt8,
)
print("Exported INT8 ONNX:", int8_onnx, int8_onnx.stat().st_size)

# Verify parity on 3 candidates
cands = ["click Button Phone", "click Button Messages", "click Button Settings"]
batch = tokenizer(
    ["Goal: open SMS app, Send SMS to Liat that I will be late in 15 min | Screen: Phone, Messages, Maps, Settings"] * 3,
    cands,
    padding=True,
    truncation=True,
    max_length=256,
    return_tensors="np"
)
with torch.no_grad():
    pt_scores = model(
        input_ids=torch.from_numpy(batch["input_ids"]),
        attention_mask=torch.from_numpy(batch["attention_mask"])
    ).logits.squeeze(-1).numpy()

sess_fp32 = ort.InferenceSession(str(fp32_onnx), providers=["CPUExecutionProvider"])
ort_fp32 = sess_fp32.run(None, {"input_ids": batch["input_ids"].astype(np.int64), "attention_mask": batch["attention_mask"].astype(np.int64)})[0].squeeze(-1)

sess_int8 = ort.InferenceSession(str(int8_onnx), providers=["CPUExecutionProvider"])
ort_int8 = sess_int8.run(None, {"input_ids": batch["input_ids"].astype(np.int64), "attention_mask": batch["attention_mask"].astype(np.int64)})[0].squeeze(-1)

print("Scores PyTorch FP32:", pt_scores)
print("Scores ORT FP32:    ", ort_fp32)
print("Scores ORT INT8:    ", ort_int8)
print("Best candidate PyTorch:", cands[int(np.argmax(pt_scores))])
print("Best candidate ORT INT8:", cands[int(np.argmax(ort_int8))])
