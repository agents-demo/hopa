# Status

**2026-11-06.** The repository is a working PC-tethered agent plus a building
HarmonyOS app. The Python harness captures an observation, asks a model for one
action, classifies it, executes it, re-observes, verifies and appends a
hash-chained record. It has 149 agent tests (228 across the harness) and a
validated 20-task bench format. The ArkTS `app/core` now has a screen-aware
payment gate and a loop that captures observations; the HAP builds with DevEco
6.1.1 / API 24 and the Local Tests pass. The entry UI is still a shell, the HAP
is unsigned, and the running Pura 90 emulator is on its lock screen, which
blocks `uitest`. No ACL has been filed. The standalone claim is still **not**
met; the toolchain and tethered claims are.

| Area | State | Evidence |
|---|---|---|
| `agent/` loop, gate, policy, records | working, tested | `pytest agent` |
| `brain/` Kotlin router + HTTP service + knowledge loader + prompts | working, 67 assertions + schema contract | `scripts/brain.ps1` |
| `pc-agent` CLI + MCP | working; live device commands work | `pc-agent devices` |
| `bench` 20 task definitions | valid | `pytest bench`, `validate` |
| Observation/action/decision/record schemas | v1 | `schemas/` |
| ArkTS `app/core` | screen-aware gate + observation loop; hypium pass | `hvigorw test` |
| HAP | builds, unsigned | `hvigorw assembleHap` |
| Accessibility extension | empty, not declared | `module.json5` |
| Emulator | Pura 90, API 24, locked screen | `hdc` |
| ACL | not filed | Phase 0 box open |
| Bench on a real model | not run | needs an unlocked device |
| Payment refusal on a real checkout | not run | needs an unlocked device |

## What works now

```bash
hopa-agent observe --json
hopa-agent run "..." --steps steps.json
hopa-agent records --path .hopa/runs.jsonl
hopa-agent verify-chain --path .hopa/runs.jsonl

cd app
hvigorw assembleHap --no-daemon
hvigorw test -p module=core@default --no-daemon -p coverage=false
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
