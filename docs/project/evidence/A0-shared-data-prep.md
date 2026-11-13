# A0 - Shared data and Harmony regression (2026-11-13)

This is the evidence for ADR-0018 and for the claim that the Harmony phone and
laptop apps still work after the data was moved out of their code.

## Environment

| Item | Value |
|---|---|
| Host | Windows, repository at `C:\Workspace\openjiuwenothers\hopa` |
| DevEco Studio | 6.24.2 (hvigor 6.24.2, JDK 17, SDK 6.1.1(24)) |
| Phone | `HBP-AL00`, HUAWEI Pura 70 Ultra, API 26 |
| Laptop | `HAD-W32`, HUAWEI MateBook Pro (`2in1`), API 26 |
| Transport | `hdc` over USB; UI driven with `uitest uiInput` |

## What changed

| Change | Files |
|---|---|
| Neutral catalogue and two renderers | `contracts/catalog/catalog.v1.json`, `tools/scripts/build-app-catalog.py` |
| Eight lost Chinese aliases repaired while regenerating the catalogue | `services/brain/knowledge/apps/{alipay,baidu,jd,quark,qunar,taobao,ctrip,wps}/APP.md` |
| Approval vocabulary moves to data | `contracts/policy/approval.v1.json`, `tools/scripts/build-policy-data.py`, `apps/harmony/core/.../gate/PolicyData.ets`, `ApprovalPolicy.ets` |
| Prompt promises become a tested contract | `contracts/prompts/rules.v1.json`, `tools/scripts/build-prompt-rules.py`, `apps/harmony/core/.../agent/PromptRules.ets`, `PromptContract.test.ets` |
| Routing cases | `contracts/fixtures/routing.json`, `tools/checks/check-routing.py` |
| Observation limits and hash vector | `contracts/observation/limits.v1.json`, `contracts/fixtures/observation-hash.json`, `tools/checks/check-observation-hash.py` |
| Decision and explanation | `docs/design/decisions/0018-shared-data-per-client-code.md`, `docs/reference/shared-data.md` |
| CI and the local test script | `.github/workflows/ci.yml`, `tools/scripts/run-tests.ps1` |

## Checks

| Check | Result |
|---|---|
| `pytest tools/scripts` | 51 passed |
| `ruff check tools services` | clean |
| `check-links.py` | 0 broken |
| `check-tree.py` | 0 violations |
| `check-conformance.py` | 0 problems |
| `check-routing.py` | 0 problems |
| `check-observation-hash.py` | 0 problems |
| `build-app-catalog.py --check` | 35 apps, 21 sites current |
| `build-policy-data.py --check` | current |
| `build-prompt-rules.py --check` | 12 rules current |
| `plan-status.py --lint` | main 97.4% (152 boxes, R15 included) |

The ArkTS core suite ran through `hvigorw test -p module=core@default`:

```
Success: 110
Fail: 0
Classes: 17
BUILD SUCCESSFUL
```

The catalogue rendering is byte-identical to the committed ArkTS except for the
added `// Source:` line, so the app reads the same 35 apps and 21 sites.

## Builds

`hvigorw assembleHap --no-daemon` finished `BUILD SUCCESSFUL` and produced:

| HAP | Size |
|---|---|
| `apps/harmony/phone/build/default/outputs/default/entry-default-signed.hap` | 2 925 KiB |
| `apps/harmony/laptop/build/default/outputs/default/laptop-default-signed.hap` | 1 482 KiB |

Both installed with `hdc install -r` on the devices above. After the alias repair
the catalogue was regenerated and both HAPs were rebuilt; `hvigorw assembleHap`
reported `BUILD SUCCESSFUL` again and both devices accepted the new HAP. The
phone locked before the rebuilt app could be brought to the foreground, so the
turn below is from the build immediately before the alias change (the loop and
policy code are identical; only alias strings differ, and the ArkTS suite covers
the routing data).

## Device turns

Both turns used the model key already configured on the device
(`deepseek-v4-flash`); no bridge was connected for either turn, so this is the
text-only loop path.

| Device | Prompt | Answer | Evidence |
|---|---|---|---|
| Phone | `What is 2 plus 2?` | `2 plus 2 is 4.` with `Done.` | [`phone-turn-2026-11-13.jpeg`](../../media/phone-turn-2026-11-13.jpeg) |
| Laptop | `What is 3 plus 4?` | `3 plus 4 is 7.` | [`laptop-turn-2026-11-13.jpeg`](../../media/laptop-turn-2026-11-13.jpeg) |

Navigation was exercised as well: the phone opened Capabilities (Launchpad,
Browser, Memory, Runs, Usage, MCP, Skills) and returned to Chat; the laptop
opened Settings (Model, Bridge, Modes, About) and returned to the conversation.

## What this does not prove

- Not every screen or gesture was exercised; the plan's A14 parity matrix is
  still the place for that.
- No bridge was running, so `observe`/`tap` over `hdc`, voice and sync were not
  part of this turn.
- The accessibility grant on the phone was not re-requested; the app reported
  `Phone` as the target and the PC bridge as offline.
- Android is still design-only: no Android code exists yet.
