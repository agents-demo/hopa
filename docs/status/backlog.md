# HOPA status and backlog

Updated 2026-11-11. Two shells: phone (`2SX0224410054549`) and MateBook 2-in-1
(`3QC0225821000268`, HarmonyOS 7.0.0.111, API 26). Shared code lives in
`@hopa/app`; the bridge is `services/pc-agent`.

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
| Verification pass | 1.5 | seven behaviours built but unseen: browser Close, Enter sends, search height, notification Stop, Kid layout, rename-by-hover, the rail's evidence block |
| Surface freeze | 0.5 | see above |
| Split the oversized pages | 1.0 | `ChatPage` 1159, `SettingsPage` 801, `LaptopIndex` 3106, `BridgeClient` 519 lines: the structure gate reports them as grandfathered debt |
| Buffer | 1.0 | |
| **Total** | **13.0** | |

## Runbook

```powershell
# build + install + screenshots both devices
powershell -ExecutionPolicy Bypass -File tools\scripts\deploy.ps1

# one bridge for every device (one port, role routing)
powershell -ExecutionPolicy Bypass -File tools\scripts\bridges.ps1

# repair the shared store if a thread ever balloons again
py -3 tools/scripts/repair-chats.py
```

Laptop launch hooks: `--ps hopa.bridge_url`, `hopa.bridge_key`, `hopa.ask`,
`hopa.new 1`, `hopa.page_ask`, `hopa.laptop.new`. Phone: `hopa.bridge_url`,
`hopa.bridge_token`, `hopa.ask`.
