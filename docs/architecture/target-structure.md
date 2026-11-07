# Target structure (proposal)

Status: **proposal, not executed.** This is the structure I recommend and the
order I would migrate in. Each phase is meant to be a separate, CI-green change
with no behaviour change.

## 1. Why now: the audit

| Area | Size | Biggest file | What hurts |
|---|---|---|---|
| Harmony UI | 14 source `.ets` in `entry` | `pages/Index.ets`, **2680 lines** | every screen, drawer, route, dialog and helper lives in one file |
| Harmony services | 14 `.ets` in `entry/service` | `AgentService.ets`, **527 lines** | one singleton owns model setup, runs, batch, schedules, exports, approvals, bridge, memory and skills |
| Harmony core | 18 source `.ets` | `Types.ets` (5 types), `Skills.ets` (2 classes), `Schedules.ets` (2 classes) | folderless: domain, agent loop, gate, model clients and stores sit side by side |
| Harmony capabilities | 4 modules | `a11y/A11yBridge.ets`, 248 lines | `a11y`/`web` abbreviations; `RemoteBridge` + `RemoteUiCapability` live in `entry/service` instead of a capability |
| Python harness | 37 `.py` in `agent` | `observation.py`, 376 | flat package; domain, loop, safety and integrations mixed |
| Python device | 17 `.py` in `pc-agent` | `mcp_server.py`, 274 | flat package; transport, device actions, API and CLI mixed |
| Kotlin brain | 13 `.kt` | `Server.kt`, 231 | already single-purpose files, but no packages |
| Docs | 43 `.md` | `rebuild-plan.md`, **73 KB** | flat `docs/`; plans, guides, reference and history in one folder |
| Tooling | 24 files in `scripts` | `sign-app.ps1`, 232 | one folder for build, signing, catalog, plan, bench and release |

The app is robust because it was built incrementally. It is hard to navigate
because every new feature was appended to the same three places. The refactor
is about naming, boundaries and one responsibility per file, not about changing
behaviour.

## 2. Principles

1. **One reason to change per file.** A page file renders one screen. A store
   file persists one kind of data. A client file talks to one API.
2. **Layers point one way:** `entry` -> `capabilities` -> `core`. A capability
   never imports another capability. `core` never imports an OS kit.
3. **Strong names, no abbreviations:** `Accessibility`, not `A11y`; `Browser`,
   not `Web`; `BridgeClient`, not `RemoteBridge`.
4. **Folders are plural collections**, files are one thing: `pages/chat/`,
   `ChatPage.ets`, `ChatComposer.ets`, `ConversationStore.ets`.
5. **No junk drawers.** No `utils`, `helpers`, `common`, `misc`. If a file has
   no clear owner, the boundary is wrong.
6. **`Index.ets` is only a public barrel** for an ArkTS package. No other file
   is named `Index`.
7. **Generated code is quarantined** in `generated/`, with a header and a CI
   staleness check.
8. **Tests mirror the layer:** `src/test/agent/AgentLoop.test.ets` for
   `src/main/ets/agent/AgentLoop.ets`; `tests/device/test_layout.py` for
   `device/layout.py`.
9. **Docs mirror the code:** architecture, guides, reference, product,
   operations, plan, history.
10. **Budgets are enforced:** pages <= 300 lines, services <= 250, core files
    <= 250. A CI check warns, then fails above 2x.

## 3. Target top level

```
hopa/
├─ apps/
│  └─ harmony/                 # DevEco project root (today: app/)
├─ services/
│  ├─ pc-agent/                # hopa_pc_agent (today: pc-agent/)
│  └─ brain/                   # Kotlin knowledge router (today: brain/)
├─ harness/
│  ├─ agent/                   # hopa_agent reference loop (today: agent/)
│  └─ bench/                   # hopa_bench (today: bench/)
├─ contracts/
│  └─ schemas/                 # today: schemas/
├─ tools/
│  ├─ scripts/                 # today: scripts/
│  ├─ signing/                 # today: signing/ (gitignored)
│  └─ checks/                  # new: import rules, budgets, doc links
├─ docs/
├─ .github/
├─ README.md
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ CODEOWNERS
├─ SECURITY.md
├─ LICENSE
├─ NOTICE
├─ CLAUDE.md
├─ .editorconfig
├─ .gitignore
└─ .gitleaks.toml
```

Why `apps/` + `services/` + `harness/`: it answers "what runs where" before you
open a folder. The only shippable app is `apps/harmony`; the PC services are
not shipped with it; the harness evaluates agents and never ships.

## 4. Target Harmony app

```
apps/harmony/
├─ AppScope/
├─ core/                                  # @hopa/core: domain + application logic
│  ├─ Index.ets                           # the only barrel
│  └─ src/
│     ├─ main/ets/
│     │  ├─ domain/
│     │  │  ├─ Action.ets                 # from Types.ets
│     │  │  ├─ Observation.ets
│     │  │  ├─ ActionOutcome.ets
│     │  │  ├─ RiskLevel.ets
│     │  │  └─ Screen.ets
│     │  ├─ agent/
│     │  │  ├─ AgentLoop.ets              # orchestration only
│     │  │  ├─ PromptBuilder.ets          # extracted from AgentLoop
│     │  │  ├─ ActionParser.ets           # extracted from AgentLoop
│     │  │  └─ ContextBudget.ets
│     │  ├─ gate/
│     │  │  ├─ ApprovalPolicy.ets
│     │  │  ├─ ActionExecutor.ets
│     │  │  ├─ ActionGuard.ets            # interface + allow-list guard
│     │  │  └─ Verifier.ets               # interface + AllowAllVerifier
│     │  ├─ model/
│     │  │  └─ ModelClient.ets            # interface + request/response only
│     │  ├─ memory/MemoryExtractor.ets
│     │  ├─ skills/
│     │  │  ├─ Skill.ets                  # from Skills.ets
│     │  │  ├─ SkillBook.ets
│     │  │  └─ SkillDrafter.ets
│     │  ├─ runs/
│     │  │  ├─ RunRecord.ets              # from Types.ets
│     │  │  ├─ RunStore.ets
│     │  │  └─ BatchRunner.ets
│     │  ├─ schedules/ScheduleBook.ets    # from Schedules.ets
│     │  ├─ conversations/ChatHistory.ets
│     │  └─ tools/ToolRegistry.ets
│     └─ test/                            # mirrors main/ets
├─ capabilities/
│  ├─ accessibility/                      # was a11y
│  │  ├─ Index.ets
│  │  └─ src/main/ets/
│  │     ├─ AccessibilityBridge.ets       # was A11yBridge
│  │     ├─ AccessibilityCapability.ets   # was A11yCapability
│  │     ├─ UiActionCapability.ets        # was UiCapability
│  │     ├─ UiLauncher.ets                # interface only
│  │     └─ extension/AccessibilityExtension.ets
│  ├─ browser/                            # was web
│  │  └─ src/main/ets/BrowserCapability.ets   # was WebCapability
│  ├─ llm/                                # NEW: the three HTTP clients leave core
│  │  └─ src/main/ets/
│  │     ├─ OpenAiCompatibleClient.ets
│  │     ├─ AnthropicClient.ets
│  │     └─ GeminiClient.ets
│  ├─ bridge-client/                      # NEW: was entry/service/Remote*
│  │  └─ src/main/ets/
│  │     ├─ BridgeClient.ets              # was RemoteBridge
│  │     └─ BridgeUiCapability.ets        # was RemoteUiCapability
│  ├─ sandbox/
│  └─ system/
├─ entry/
│  └─ src/main/ets/
│     ├─ entryability/EntryAbility.ets
│     ├─ extension/HopaAccessibilityExtension.ets
│     ├─ navigation/
│     │  ├─ Route.ets                     # enum, one route per screen
│     │  ├─ AppShell.ets                  # sidebar + header + host
│     │  ├─ Drawer.ets
│     │  └─ RouteHost.ets
│     ├─ pages/
│     │  ├─ chat/                         # ChatPage, ChatComposer, MessageList
│     │  ├─ plans/PlansPage.ets
│     │  ├─ memory/                       # MemoryPage, FactsList, SkillsList
│     │  ├─ browser/BrowserPage.ets
│     │  ├─ apps/                         # AppsPage, AppList, SiteList
│     │  ├─ runs/                         # RunsPage, BatchForm, RunList, RunDetailPage
│     │  ├─ settings/                     # SettingsPage, AppAccess, ComputerAccess,
│     │  │                                # SelfCheck, Developer, About, License
│     │  ├─ models/ModelsPage.ets
│     │  ├─ usage/UsagePage.ets
│     │  ├─ phone/PhoneSetupPage.ets
│     │  ├─ screens/ScreensPage.ets
│     │  └─ tools/                        # More, Source, McpServers, Files, Welcome
│     ├─ components/                      # MenuRow, SectionHeader, MetricRow,
│     │                                   # TimelineRow, CodeBlock, EmptyState, StatusPill
│     ├─ services/
│     │  ├─ AgentRuntime.ets              # run / cancel / continue / busy
│     │  ├─ ConversationService.ets       # ChatHistory + persistence
│     │  ├─ ScheduleService.ets           # ScheduleBook + timer + persistence
│     │  ├─ SettingsRepository.ets        # SettingsStore
│     │  ├─ ExportService.ets             # exportData
│     │  ├─ ApprovalPromptService.ets     # UiApprovalGateway
│     │  ├─ ModelFactory.ets              # provider -> client
│     │  ├─ MemoryStore.ets
│     │  ├─ SkillStore.ets
│     │  ├─ BrowserController.ets
│     │  ├─ JsSandboxBridge.ets
│     │  ├─ AppLauncher.ets
│     │  └─ BackgroundKeeper.ets
│     └─ generated/AppCatalog.ets         # was service/AppCatalog.ets
└─ resources/ (per module, unchanged)
```

`Index.ets` stays only as each package's public API. Everything else is named
after what it does.

## 5. Target Python and Kotlin

```
services/pc-agent/src/hopa_pc_agent/
├─ errors.py
├─ transport/hdc.py                 # process wrapper only
├─ device/device.py                 # taps, typing, launch
├─ device/layout.py                 # parsing and querying the UI tree
├─ device/apps.py                   # installed-app listing
├─ api/bridge.py                    # HTTP bridge handler
├─ api/mcp_server.py                # MCP stdio server
└─ cli/ (main.py, device_commands.py, bridge_commands.py, app_commands.py)

harness/agent/src/hopa_agent/
├─ domain/ (actions.py, observation.py, records.py, models.py)
├─ runtime/ (loop.py, executor.py, runtime.py, capture.py, limits.py)
├─ safety/ (policy.py, refusal.py)
├─ integrations/ (brain.py, net.py)
├─ diagnostics/logging.py
├─ cli/main.py
└─ errors.py

services/brain/src/main/kotlin/hopa/brain/
├─ http/Server.kt
├─ routing/Router.kt
├─ knowledge/ (KnowledgeLoader.kt, SiteLoader.kt, SkillLoader.kt)
├─ prompts/Prompts.kt
├─ demo/DemoEntries.kt
└─ knowledge/ (data: apps/, sites/, skills/ stay as data, not code)

harness/bench/src/hopa_bench/
├─ tasks.py, runner.py, scoring.py, cli.py
├─ tasks/                          # the 20 task files
└─ results/                        # gitignored
```

Tests mirror the package tree, e.g. `services/pc-agent/tests/device/test_layout.py`.

## 6. Target docs

```
docs/
├─ README.md                       # index of the index
├─ architecture/
│  ├─ overview.md                  # from architecture.md
│  ├─ layers.md                    # the dependency rules, with the import lint
│  ├─ data-flow.md                 # observation -> model -> gate -> action -> record
│  └─ decisions/ADR-0001-....md    # one decision per file
├─ guides/
│  ├─ setup.md                     # from setup.md
│  ├─ build-and-sign.md            # from signing.md + setup build part
│  ├─ device-testing.md            # from a11y.md + emulator notes
│  ├─ pc-bridge.md                 # from bridge.md
│  └─ troubleshooting.md           # from emulator-crash + faq
├─ reference/
│  ├─ protocols.md                 # bridge, brain HTTP, MCP, in one place
│  ├─ schemas.md                   # the four JSON schemas
│  ├─ app-catalog.md               # bundles, apps, sites, UNCONFIRMED rule
│  ├─ glossary.md
│  ├─ safety.md
│  ├─ threat-model.md
│  ├─ privacy.md
│  └─ abuse.md
├─ product/
│  ├─ parity.md                    # from mika-parity.md
│  ├─ roadmap.md
│  ├─ ux.md
│  ├─ bench.md                     # from bench-v0.md + eval.md
│  └─ release.md
├─ operations/
│  ├─ ci.md
│  ├─ owners.md
│  ├─ versioning.md
│  ├─ definition-of-ready.md
│  └─ sbom.json
└─ plan/
   ├─ README.md                    # what the plan is, how it is scored
   ├─ phase-0-foundations.md       # split from the 73 KB rebuild-plan.md
   ├─ phase-1-...md
   └─ progress.md                  # generated by plan-status.py
```

`history/` keeps dated snapshots (`status-2026-11-07.md`, `port-log.md`,
`emulator-crash-2026-11-06.md`). Status is not a permanent product doc; it is
a log.

## 7. Naming rules

| Today | Target | Rule |
|---|---|---|
| `a11y` | `accessibility` | no abbreviations in folders or public names |
| `WebCapability` | `BrowserCapability` | domain word, not the platform word |
| `A11yBridge` | `AccessibilityBridge` | same |
| `UiCapability` | `UiActionCapability` | say what it does |
| `RemoteBridge` | `BridgeClient` | role, not transport |
| `RemoteUiCapability` | `BridgeUiCapability` | owner + role |
| `Types.ets` | `Action`, `Observation`, `ActionOutcome`, `RiskLevel`, `RunRecord` | one export per file |
| `Skills.ets` | `Skill.ets` + `SkillBook.ets` | one class per file |
| `Schedules.ets` | `ScheduleBook.ets` | file named after the class |
| `service/` | `services/` | plural collection |
| `pages/Index.ets` | `pages/<area>/<Area>Page.ets` | screen per file |
| `AgentService` | `AgentRuntime` + services | one concern per service |

## 8. Dependency rules (enforced)

```
entry          -> core, capabilities, OS kits
capabilities   -> core only, plus their own OS kit
core           -> no @kit.* imports at all
tests          -> the layer they test
```

Consequences:

- The three LLM HTTP clients move from `core` to `capabilities/llm`. `core`
  keeps `ModelClient`, `ModelRequest`, `ModelResponse` (pure data).
- `BridgeClient` becomes a capability; the entry only wires it.
- No capability imports another capability. `UiLauncher` stays an interface
  owned by accessibility and implemented in entry.
- `tools/checks/check-structure.py` parses imports and fails CI on violations.
  It also enforces the file-size budgets and that `Index.ets` is a barrel.

## 9. Splitting `Index.ets` (2680 lines)

| Today (builder) | Target file |
|---|---|
| `ChatPage` | `pages/chat/ChatPage.ets` (+ `ChatComposer.ets`, `MessageList.ets`) |
| `WebPage` | `pages/browser/BrowserPage.ets` |
| `AppsPage`, `AppsListSection`, `SitesListSection` | `pages/apps/` (3 files) |
| `PlansPage` | `pages/plans/PlansPage.ets` |
| `RunsPage` | `pages/runs/RunsPage.ets` (+ `BatchForm.ets`, `RunList.ets`) |
| `RunDetailPage`, `TimelineRow` | `pages/runs/` |
| `SettingsPage`, `SettingsRow` | `pages/settings/SettingsPage.ets` |
| `AppAccessPage` | `pages/settings/AppAccessPage.ets` |
| `ComputerAccessPage` | `pages/settings/ComputerAccessPage.ets` |
| `SelfCheckPage` | `pages/settings/SelfCheckPage.ets` |
| `DeveloperPage` | `pages/settings/DeveloperPage.ets` |
| `AboutPage`, `LicensePage` | `pages/settings/` |
| `ModelsPage`, `UsagePage`, `PhonePage` | `pages/models/`, `pages/usage/`, `pages/phone/` |
| `ScreensPage` | `pages/screens/ScreensPage.ets` |
| `MoreToolsPage`, `SourcePage`, `McpServersPage`, `FilesPage`, `WelcomePage` | `pages/tools/` |
| `MemoryPage`, `FactsSection`, `SkillsSection` | `pages/memory/` |
| `Drawer`, `DrawerItem`, `PageHost`, `SettingsHost`, `MoreContainer` | `navigation/` |
| `MoreRow`, `ToolRow`, `UsageLine`, `CheckLine`, `SourceLine`, `DevLine` | `components/MenuRow.ets`, `MetricRow.ets`, `StatusRow.ets` |

## 10. Splitting `AgentService` (527 lines)

| Concern | Target |
|---|---|
| `run`, `runInner`, `runBatch`, cancel, continue, busy counter | `services/AgentRuntime.ets` |
| provider/endpoint/model/key -> client, `hasModel`, labels | `services/ModelFactory.ets` |
| approval dialog handler, fail-closed gateway | `services/ApprovalPromptService.ets` |
| `exportData`, `loadRuns`, `saveRuns` | `services/ExportService.ets` / `RunStore` |
| schedules load/save/tick | `services/ScheduleService.ets` |
| bridge configure/health/wiring | `services/BridgeService.ets` (or the capability) |
| memory/skills load/save | `MemoryStore`, `SkillStore` (already separate) |
| catalog -> prompt list | `services/AppCatalogPrompt.ets` |

`AgentService` can survive briefly as a facade during phase 9, then be deleted.

## 11. Migration phases

Each phase is a separate change; CI and `run-tests.ps1` must stay green. No
behaviour changes in phases 1-8.

| # | Phase | Scope | Risk | Est. |
|---|---|---|---|---|
| 0 | Safety net | add `tools/checks/check-structure.py`, file budgets, ADR template | low | S |
| 1 | Docs | create tree, `git mv` files, split rebuild-plan, fix links, add link check | low | M |
| 2 | Tooling | move `scripts/` + `signing/` to `tools/`, update CI and docs | low | S |
| 3 | Contracts | move `schemas/` to `contracts/schemas/`, update references | low | S |
| 4 | Python packages | move `agent/`, `pc-agent/`, `bench/` under `harness/` and `services/`, update pyprojects + CI | medium | M |
| 5 | Brain packages | group Kotlin files into packages, update tests | low | S |
| 6 | Harmony root | move `app/` -> `apps/harmony/`, update scripts + CI + docs | medium | M |
| 7 | LLM boundary | extract `capabilities/llm`, keep core pure, move client tests | medium | M |
| 8 | Core split | split `Types`, `Skills`, `Schedules`; create subfolders; update barrel + tests | medium | L |
| 9 | Service split | one commit per service out of `AgentService`; facade until last | high | L |
| 10 | Page split | components first, then one page per commit, then navigation | high | XL |
| 11 | Renames | `a11y` -> `accessibility`, `web` -> `browser`, class renames, `bridge-client` module | medium | M |
| 12 | Enforcement + docs | turn on import/link/size checks, write layers + data-flow, ADRs | low | S |

`XL` only because of review size, not uncertainty: phase 10 is mechanical once
the navigation shell is stable.

## 12. Risks and how to keep them small

- **ArkUI state across pages.** Do not introduce a state framework. Keep state
  in the page component; extract stateless widgets first, then pages with
  `@Prop`/callbacks. One page per commit, each verified by a build.
- **Module renames break imports.** Do them in one commit with the `oh-package`
  and `build-profile.json5` updates; the compiler is the test.
- **DevEco project path.** `.idea` is gitignored, so moving the project root is
  safe; every script and CI path must change in the same commit.
- **Generated catalog.** Keep the generator path parameterised; the staleness
  check must point at `generated/AppCatalog.ets`.
- **Docs links.** Add `tools/checks/check-links.py` and run it in CI before the
  big moves; links are the most likely silent breakage.
- **Git history.** Use `git mv` for every file move so blame survives.
- **Emulator flakiness.** Phases 1-8 are compile/test-only. On-device checks
  only after phases 9-11, when the UI is rebuilt.

## 13. Out of scope

- No behaviour changes, no new features, no redesign of the screens.
- No new dependencies.
- No port of Mika code.
- The signing kit stays local and gitignored; it is only relocated.

## 14. Open decisions

1. **Top-level names.** Recommended `apps/harmony`, `services/*`, `harness/*`.
   Alternative: keep `app/` and only add `services/` + `harness/`.
2. **Core purity.** Recommended: move the HTTP model clients to
   `capabilities/llm`. Alternative: keep them in `core/model` and weaken the
   rule to "core may use @kit.NetworkKit".
3. **Plan docs.** Recommended: split the 73 KB `rebuild-plan.md` into one file
   per phase plus a generated `progress.md`. Alternative: keep one long file
   under `docs/plan/`.
