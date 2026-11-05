# Status

**2026-11-05.** The repository is an early but working PC-tethered agent. The
Python harness can capture an observation, ask a model for one action, classify
it, execute it, re-observe, verify and append a hash-chained record. It has 143
agent tests (216 across the harness) and a validated 5-task bench format. The
ArkTS app is still a shell: the HAP builds only with the Huawei toolchain, the
accessibility extension is not declared, and no device or emulator is available
on the development machine. No ACL has been filed. The standalone claim is
therefore **not** met; the tethered claim is.

| Area | State | Evidence |
|---|---|---|
| `agent/` loop, gate, policy, records | working, tested | `pytest agent` |
| `pc-agent` CLI + MCP | working | `pytest pc-agent` |
| `bench` 5 tasks | valid | `pytest bench`, `validate` |
| Observation/action/decision/record schemas | v1 | `schemas/` |
| ArkTS `app/core` | scaffold, not wired | `app/core/src` |
| Accessibility extension | empty, not declared | `module.json5` |
| Device / emulator / DevEco | absent on this machine | `hdc` not found |
| ACL | not filed | Phase 0 box open |
| Bench on a real model | not run | needs a device |
| Payment refusal on a real checkout | not run | needs a device |

## What works now

```bash
hopa-agent observe --json
hopa-agent run "..." --steps steps.json
hopa-agent records --path .hopa/runs.jsonl
hopa-agent verify-chain --path .hopa/runs.jsonl
```

## What is next

1. Bench v0: run the 5 tasks through the new loop with the stub model.
2. Add `node_exists`, `app_foreground` and `screen_hash` predicates.
3. Fill `docs/baseline.md` on a real device.
4. File the ACL request.
5. Start the JVM brain extraction.

## Honest limits

- There is no background screen and no hidden virtual display.
- The HAP contains no Python runtime.
- The phone app cannot control other apps until the ACL is approved.
- Numbers in this repository are local until a device run says otherwise.
