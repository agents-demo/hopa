# Status

**2026-11-06.** The repository is a working PC-tethered agent plus a signed,
installed HarmonyOS app. The Python harness captures an observation, asks a
model for one action, classifies it, executes it, re-observes, verifies and
appends a hash-chained record. It has 188 agent tests (268 across the harness)
and a validated 20-task bench format. The ArkTS `app/core` has a screen-aware
payment gate and a loop that captures observations; the HAP builds with DevEco
6.1.1 / API 24, the Local Tests pass, and the HAP is signed with the SDK's local
OpenHarmony debug kit and installed on the Pura 90 emulator (`bm install` ok,
`EntryAbility` starts, first frame drawn, all four tabs render). The chat page is
wired to `AgentLoop`: with a model configured it captures the screen, asks for
an action, gates it, executes it and records it. The approval gateway is
fail-closed and opens an ArkUI dialog. The loop still cannot see other apps
because the accessibility extension is not declared and no ACL is filed. The
standalone claim is still **not** met; the toolchain, tethered, install and
UI-wiring claims are.

Plan progress: **226 / 767 boxes (29.5%)**. The open boxes are concentrated in
the device/ACL, UI, release and sign-off phases.

| Area | State | Evidence |
|---|---|---|
| `agent/` loop, gate, policy, records | working, tested | `pytest agent` |
| `brain/` Kotlin router + HTTP service + knowledge + prompts + skills + sites | working, 98 assertions + schema contract | `scripts/brain.ps1` |
| `pc-agent` CLI + MCP | working; live device commands work | `pc-agent devices` |
| `bench` 20 task definitions | valid | `pytest bench`, `validate` |
| Observation/action/decision/record schemas | v1 | `schemas/` |
| ArkTS `app/core` | screen-aware gate + observation loop; OpenAI, Anthropic and Gemini clients; hypium pass | `hvigorw test` |
| HAP | builds and signed with the local debug kit | `scripts/sign-app.ps1` |
| Installed on the emulator | yes: launch, first frame, four tabs | `hdc install -r` |
| Entry UI | chat wired to `AgentLoop`; fail-closed approval dialog; provider settings; memory and skills; built-in Web tab | `pages/Index.ets` |
| Accessibility extension | bridge compiled; not declared; no ACL | `docs/a11y.md` |
| Emulator | Pura 90, API 24, locked screen | `hdc` |
| ACL | not filed | Phase 0 box open |
| Bench on a device (stub model) | 5/7 on the tasks this image can run (3/5 on the original five) | `docs/bench-v0.md` |
| Bench on a real model | not run | needs a real key |
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

Sign and install with the SDK's local OpenHarmony debug kit (no Huawei account):

```powershell
.\scripts\build.ps1
.\scripts\sign-app.ps1 -Install
```

`signing/` is gitignored; `scripts/sign-app.ps1` regenerates the app key, the
certificate chain, the debug profile (with the connected device's UDID) and the
signed HAP on any machine that has the SDK.

## What is next

1. Wire `Index.ets` to `AgentLoop` so a chat message runs on-device.
2. File the accessibility ACL request and declare the extension.
3. Add `node_exists`, `app_foreground` and `screen_hash` predicates.
4. Fill `docs/baseline.md` on a real device.
5. Bench v0 on a real model.

## Honest limits

- There is no background screen and no hidden virtual display.
- The HAP contains no Python runtime.
- The phone app cannot control other apps until the ACL is approved.
- Numbers in this repository are local until a device run says otherwise.

