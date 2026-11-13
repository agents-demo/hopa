# HOPA status and backlog

Updated 2026-11-13. **Android is the active client; Windows is next; Harmony is
frozen (ADR-0020).** The Harmony notes below describe the shipped app, not the
active roadmap. Harmony debts are deferred maintenance, not prerequisites for
Android or Windows.

**Android now runs:** the debug app launches on an API 35 emulator with the loop,
chat, settings, conversations, profiles, runs, capabilities and launchpad; the
bridge, accessibility, Room persistence and approval sheet are next
(`docs/project/evidence/A0-android-running.md`).

Two shells: phone (`2SX0224410054549`) and MateBook 2-in-1
(`3QC0225821000268`, HarmonyOS 7.0.0.111, API 26). Shared app code lives in
`@hopa/app`; the services are `services/{bridge,relay,wire,brain,evals}`.

## Where the daily experience stands

| Area | State |
|---|---|
| Chat on the shared engine | done — structured answers, chips, Stop, Retry |
| Conversations | one store on the bridge; both devices read and write the same threads; grouped by recency, searchable, rename/delete via a hover menu |
| Approvals | inline card in the details rail, with the captured frame |
| Details panel | DETAILS → Your request → timing (when measured) → What HOPA sees; hidden for an empty draft |
| Voice | record here, transcribe and speak on the PC; honest failure without the bridge |
| Browser | HOPA's own ArkWeb pane: read page text, ask about it, back/forward/reload, recent pages |
| Launchpad | catalog apps installed here, opened by Want, no bridge needed |
| Plans | schedules run while HOPA is open |
| Memory, Skills | persisted, editable, deletable |
| Usage, Capabilities | honest pages; capabilities says yes / bridge / no |
| Modes | five; Easy/Kid hide the rail; Kid hides the history and needs a parent PIN |
| Desktop | window size/position memory, hover states, Ctrl+K palette, focusable rows |
| Packaging | 2in1 + tablet only, laptop-body icon, 960×620 minimum window |

## Known defects and limits

| Item | Detail |
|---|---|
| Window surface freezes | after many force-stops the 2in1 keeps painting the last frame while the UI tree is current. Close the window and reopen (or reboot) before judging the UI. Worth 0.5 d of investigation |
| MCP | `AgentLoop` has no tool-calling path: schemas, function-call parsing and execution must exist before MCP can do anything |
| Taskbar shortcuts | this SDK level rejects `shortcuts` in `module.json5`; `hopa://activity` is handled if a launcher sends it |
| Phone bridge key | a bridge restart invalidates a *paired* token; the static key survives. `/whoami` is the honest check, `/health` is not |
| Terminal note | `hdc install` drops reverse ports; `deploy.ps1` and `bridges.ps1` restore them |

## Backlog

| Item | d | Notes |
|---|---|---|
| MCP over HTTP | 3.0 | engine tool-calling first |
| Chinese strings (no RTL) | 2.5 | both shells; extract resources, then translate |
| Fold/tablet remainder | 1.5 | two-pane fold states, tablet widths |
| Desktop leftovers | 2.0 | focus ring styling, taskbar alternative |
| Verification pass | 1.5 | behaviours built but unseen: browser Close, search height, notification Stop, Kid layout, rename-by-hover, the rail's evidence block. (Enter/Shift+Enter, mic and the arrow are verified on 2026-11-12) |
| Surface freeze | 0.5 | see above |
| Split the oversized pages | 1.0 | `ChatPage` 1137, `SettingsPage` 852, `LaptopIndex` 3545, `BridgeClient` 557 lines: the structure gate reports them as grandfathered debt |
| Buffer | 1.0 | |
| **Total** | **13.0** | |

## Runbook

```powershell
# build + install + screenshots both devices
powershell -ExecutionPolicy Bypass -File tools\scripts\deploy.ps1

# one bridge for every device (one port, role routing)
powershell -ExecutionPolicy Bypass -File services\tools\scripts\bridges.ps1

# repair the shared store if a thread ever balloons again
py -3 services/tools/scripts/repair-chats.py
```

Laptop launch hooks: `--ps hopa.bridge_url`, `hopa.bridge_key`, `hopa.ask`,
`hopa.new 1`, `hopa.page_ask`, `hopa.laptop.new`. Phone: `hopa.bridge_url`,
`hopa.bridge_token`, `hopa.ask`.

## Structure

The structural refactor is done; its evidence is in `docs/project/plan/README.md`.
Gates it established: `check-tree`, `check-links`, `check-openapi`,
`check-render`, scoped ruff, and `pytest.ini` with `--import-mode=importlib`.

## Known behaviour (from the 2026-11-12 E2E)

- A nonsense prompt can make the model repeat the previous turn's action: after
  the Douyin run was interrupted, sending `Line a / Line b` produced an
  `ui.launch` of Douyin as the answer. The run pane attached it to that turn, so
  this is model behaviour, not a resume path (`resumeInterrupted` had no callers
  and is deleted). Fixing it is a prompt/eval task, not a structural one.
