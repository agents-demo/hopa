# hopa-agent

The PC-side reference loop for HOPA. It is the executable twin of the ArkTS
`app/core` design and is used by the PC-tethered harness:

```
observe -> decide -> gate -> act -> verify -> record
```

It is **not** shipped in the HAP. The phone app will reimplement the same
contract in ArkTS. Keeping this loop in Python lets us test the whole control
path before the HarmonyOS toolchain and the accessibility ACL are available.

## Install

```bash
python -m pip install -e ./pc-agent -e ./agent
```

## Commands

```bash
hopa-agent observe --json
hopa-agent observe --screenshot --out .hopa/screens
hopa-agent run "Open Settings and reach Bluetooth" --max-steps 8
hopa-agent records --path .hopa/runs.jsonl
hopa-agent verify-chain --path .hopa/runs.jsonl
```

`observe` needs a device. `run` with `--model stub` needs scripted steps and a
device. Unit tests use a fake device and need neither.

## Rules this loop enforces

- Every action goes through one executor.
- The model proposes; it never classifies payment.
- A tap on a payment-looking screen always asks.
- A denied action is recorded and never executed.
- Refs expire with every observation.
- Every step is appended to a hash-chained record.
