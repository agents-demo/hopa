# Mika parity

How much of Mika exists in HOPA, what cannot be taken, and what is left for a
"kind of Mika".

Mika source: `C:\Workspace\openjiuwenothers\Mika` (Apache-2.0, 59.7 MB, core
~45k lines of **pure Kotlin** — no `android.*` imports in `core/`). The Android
app module supplies device control; HOPA must supply its own HarmonyOS layer.

## 1. User-visible capabilities

| # | Mika capability | HOPA today | Gap | Portable? |
|---|---|---|---|---|
| 1 | Operates any app **without taking over the screen** | PC-tethered control works; on-device a11y compiled but inactive | no background display; foreground a11y only | **No** (excluded) |
| 2 | Built-in desktop-class browser | single-tab ArkWeb browser; read/click/type wired; verified loading a page | tabs, downloads, uploads, sign-in | yes (ArkWeb) |
| 3 | "Act on the screen I am looking at" | none | needs a11y | partial |
| 4 | Scheduled and conditional tasks | not shipped; the system reminder API failed on the emulator (1700002) | scheduler + triggers | yes, with HarmonyOS background limits |
| 5 | Interrupt, stop, report, continue | resume exists in the Python harness; no UI | steering + UI | yes |
| 6 | Hold to talk (speech) | none | platform ASR or provider | yes |
| 7 | Ask / Autonomous modes | Ask only, fail-closed | autonomous mode | yes, by decision |
| 8 | Memory and preferences | explicit user memory, persisted, visible and deletable | learned memory + profile | yes |
| 9 | Learns skills and app knowledge | explicit personal skills + a 27-app catalogue in the app, 21 sites, 6 static skills; no auto-drafting | drafter/import/outcomes | yes |
| 10 | Batch jobs | none | batch runner | yes |
| 11 | Traceable runs | `RunStore` records only | trace, usage, cost, eval | yes |
| 12 | Linux sandbox | WASM stub, nothing bundled | Linux is out of scope; WASM only | no (Linux) |
| 13 | CLI + MCP from a computer | `pc-agent` CLI + MCP server | near parity, needs tool breadth | yes |
| 14 | Many model providers + account sign-in | OpenAI-compatible, Anthropic and Gemini | OAuth sign-in, more presets | yes |
| 15 | 10 UI languages | English only | i18n | yes |

Usable today: **~4 of 15** (browser, memory, CLI/MCP, providers; partial knowledge,
partial traceability, Ask mode). That is about **a quarter of the user-visible
surface**.

## 2. Core package matrix

Lines are Mika's Kotlin lines; they show size, not remaining work.

| Mika package | Lines | Role | HOPA state | Verdict |
|---|---|---|---|---|
| `agent` | 4,347 | loop, context builder, compaction, intent gate, review | `AgentLoop` only | port pieces |
| `action` | 1,005 | action model, parsing, effects | `Types`/`Action` | mostly done |
| `gate`, `guard`, `risk` | 1,178 | approval, guards, risk | `ApprovalPolicy` + `ActionExecutor` | mostly done |
| `verify` | 967 | evidence ledger, grounding, sources | `AllowAllVerifier` only | port |
| `model` | 2,516 | OpenAI, Anthropic, Gemini, Responses, catalog | OpenAI-compatible only | port |
| `tool` | 1,302 | tool registry, dispatch, groups, link policy | `ToolRegistry` minimal | port |
| `general` | 1,162 | general tools (memory, schedule, wait, confirm) | few tools | port |
| `context` | 64 | context primitives | inline | port |
| `prompt` | 76 | prompt book + versioning | `Prompts.kt` (brain) | port versioning |
| `memory` | 724 | memory store, extractor, index, profile | none | port |
| `skills` | 537 | personal skills, drafter, import, outcomes | static loader only | port |
| `knowledge` | 1,051 | routing, guide catalog, learning, sites | router + loaders | add catalog/learning |
| `trigger` | 267 | schedules, conditions, admin | none | port |
| `run` | 482 | run handle, inbox, steering, channels | `RunStore` | partial |
| `record` | 850 | events, metrics, redaction, metrics store | `RunStore` | port |
| `replay` | 540 | route record/replay | none | port later |
| `trace` | 807 | spans, trace files | none | port later |
| `usage` | 480 | metering, ledger, query | none | port |
| `eval` | 1,058 | checks, scoring, reports | bench (separate) | merge |
| `settings` | 79 | self-config | in-memory | port + persist |
| `selfcheck` | 356 | compatibility self-check | none | port later |
| `vision` | 355 | locator, vision service | none | port later |
| `visual` | 113 | frame grid, shot tuning | none | skip |
| `workspace` | 559 | sandbox paths, file gate | none | WASM only |
| `net` | 297 | local hosts, proxy | none | skip |
| `remote` | 1,064 | HTTP server, relay, remote tasks | pc-agent MCP | partial |
| `mcp` | 623 | MCP client and server, USB | pc-agent MCP | partial |
| `oauth` | 743 | device code, PKCE, OpenRouter/xAI | none | decision |
| `chatgpt` | 411 | ChatGPT account flow | none | decision |
| `adb`, `shell` | 3,475 | Android device control | `hdc` + `uitest` | **not takable** |
| `access`, `cap`, `uistate`, `userscreen`, `device`, `child`, `wechat` | ~18,000 | Android a11y engine, gestures, screen state, WeChat | a11y extension + `UiCapability` | **reimplement, not copy** |
| `assembly` | 254 | wiring | manual | skip |

The device-control group is the one place where "take everything" is impossible:
it is built on Android accessibility and a hidden display. HOPA already replaces
its *behaviour* with `hdc`/`uitest` on PC and the HarmonyOS accessibility
extension on device.

## 3. How close

| Measure | Value |
|---|---|
| User-visible capabilities usable | ~2.5 / 15 (~17%) |
| Portable core ported | ~10-15% |
| Shared product surfaces (CLI/MCP, knowledge, records) | ~50% |
| Device-control layer | replaced, not ported; on-device part blocked by ACL |

The honest summary: **the skeleton and the safety gate are ahead of Mika; the
product is far behind.** HOPA has a better-tested payment gate and a cleaner
record model. Mika has the browser, memory, skills, schedules, providers, trace,
vision and the UI that make it feel like an assistant.

## 4. Effort to "a kind of Mika"

No background screen, no Linux sandbox. Estimates are focused developer-days
for one person who knows the codebase; they are not promises.

| Milestone | Scope | Days |
|---|---|---|
| P1: usable web+chat agent | ArkWeb browser, web tools, 3-4 providers, persistent settings, memory, chat/task UI | 25-35 |
| P2: "gets better with use" | personal skills + drafter, context compaction, schedules/triggers, app/site knowledge refresh | 25-35 |
| P3: trustworthy | verify/evidence ledger, trace, usage/cost, eval merge, export/delete memory | 20-30 |
| P4: reach | OAuth sign-in, MCP server on device, remote host, speech, i18n | 25-35 |
| **Total** | | **95-135** |

P1 is the real answer to "have a kind of Mika": after P1 the app can chat, browse
and act on web pages on-device with memory, without any ACL. App operation
(foreground only) needs the ACL and stays external.

## 5. What is not takable, and what needs a decision

Not takable:

- the hidden background display (excluded by the user and by HarmonyOS);
- the Android accessibility engine and gesture pacing (rewritten, not copied);
- `adb`/`shell` device control (replaced by `hdc`/`uitest`);
- the Linux sandbox (out of scope; WASM only).

Needs a product decision before porting:

1. **Autonomous mode.** Mika lets the user switch off "ask before acting".
   HOPA is fail-closed today. Keep it that way, or add a deliberate, logged
   opt-in?
2. **Account sign-in (OAuth).** ChatGPT/xAI/OpenRouter device-code flows. Useful,
   but it stores account tokens and may conflict with provider terms.
3. **Speech input.** Platform ASR (no key, on-device) or provider speech models?
4. **MCP server on the phone.** Lets a PC drive HOPA. Mika has it; it widens the
   attack surface.
5. **Chinese-first knowledge.** Mika's app knowledge is Chinese. Do we translate
   it, keep it bilingual, or only write English entries?
6. **Browser scope.** Full desktop-class browser (tabs, downloads, uploads,
   sign-in) is a large sub-project; a single tab with read/click/type is P1 and
   the rest can follow.

## 6. What I port first

Order chosen so every step works without the ACL and without a background
screen:

1. ~~**ArkWeb browser + web tools**~~ — done: single-tab browser, read/click/type,
   page text feeds the gate.
2. ~~**Model providers + persistent settings**~~ — done: OpenAI-compatible,
   Anthropic, Gemini; endpoint/model/provider persist.
3. ~~**Memory + profile**~~ — memory done (explicit facts, persisted, deletable);
   profile extraction not started.
4. ~~**Personal skills**~~ — done: user-authored skills with trigger matching and
   prompt injection; auto-drafting not started.
5. ~~**Context builder + compaction**~~ — a bounded char budget is done; semantic
   summarization is not.
6. **Schedules/triggers** — attempted with the system reminder agent. The
   emulator rejects `publishReminder` with `1700002` even after
   `cancelAllReminders`, so the feature was removed rather than shipped broken.
   Retry on a physical device.
7. **Verify/evidence, trace, usage, eval** — trust surface.
8. **OAuth, MCP server, speech, i18n** — reach.

Progress on this list is tracked in `docs/rebuild-plan.md` Phase 3 and in the
commit log, not by inventing a second percentage.
