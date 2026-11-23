# Restructure Android app package structure

Deep critique and proposed new structure for
`apps/android/app/src/main/kotlin/com/hopa/app`.

This is a plan, not a single change. It is split into three pull requests:
mechanical moves first, then the two god classes, then the dependency-injection
decision. Nothing here changes the wire format.

---

## Architecture — the foundational problem

### `AppContainer` is a service locator, not a DI container

`AppContainer` is a 413-line singleton passed into every ViewModel constructor.
Because every screen receives the entire container, every screen can reach every
system. Nothing is explicit: you cannot tell what a feature actually needs without
reading all its code. This is the service locator anti-pattern.

### Dependency injection is its own decision, not part of moving files

The fix is not necessarily Hilt. Two options:

**A. Narrow containers (recommended first).** Split `AppContainer` into a few
explicit holders (`PlatformContainer`, `CoreContainer`) and give every ViewModel
factory only the ports its screen uses. No new plugins, no code generation, works
with the current build. This already removes the "every screen can reach every
system" property.

**B. Hilt.** Each ViewModel declares only what it needs:

```kotlin
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val conversations: ConversationStore,
    private val runs: RunCoordinator,
    private val gate: ApprovalGateway,
) : ViewModel()
```

Cost, which the earlier draft of this plan did not state: a new Gradle plugin and
KSP, `@HiltAndroidApp`, `@AndroidEntryPoint` on `MainActivity`, bindings for every
port (`DevicePort`, `ModelPort`, `Clock`, `ApprovalGateway`, …),
`hiltViewModel()` in navigation, and every existing factory rewritten. It also
lengthens every build.

Whichever option wins, it is a separate PR after the packaging settles. Doing the
settings split against factories and then converting to Hilt would throw that work
away, so the order matters. The rest of this document does not depend on the
choice.

---

## God-class violations

### `SettingsViewModel` — 731 lines, eight concerns

One ViewModel currently owns:
1. Provider/model selection and testing
2. Bridge device pairing and health checks
3. Backend gateway pairing
4. Screen mode selection (auto / background / bridge / onscreen)
5. Accessibility permission state
6. Notification testing
7. Wireless ADB pairing
8. Self-check diagnostics

Each of these is a screen in its own right. Each deserves its own ViewModel.
Modern practice: one ViewModel per screen, scoped to its NavBackStackEntry.

Proposed split inside `feature/settings/`:

```
settings/
  model/        ModelSettingsViewModel   provider, endpoint, key, test
  surface/      SurfaceSettingsViewModel screen mode, background helper
  pairing/      PairingViewModel         backend + bridge pairing flows
  diagnostics/  DiagnosticsViewModel     self-check, accessibility health
  notify/       NotifyViewModel          notification permission + test
  SettingsViewModel  ← thin coordinator for top-level settings only
```

`character` (tone, chattiness) stays in `settings/character/` only if it grows a
second screen; today it is one screen and does not need its own directory.

**A split needs one source of truth.** `SettingsRepository` already is that source:
one `Flow<AppSettings>` and focused setters, backed by DataStore and the Keystore.
Each screen ViewModel must observe that flow or read it once, and update through
the repository — not keep a private copy that drifts. Do not add a second
`SettingsStore` wrapper for the sake of the split.

### `ChatsSheet` — 435 lines, UI composable doing ViewModel work

A single `@Composable` currently handles: searching conversations, grouping by
date section (Today / Yesterday / 7 days / Older), swipe-to-dismiss, sync to
bridge, rendering cards. Search and grouping logic is embedded in the composable
and cannot be tested.

Move the found list and sync coordination into `ConversationsViewModel`. Put the
date grouping in a **pure function** (`ConversationGrouping.sections(...)`), not in
the ViewModel: it is a transformation of a list, testable without coroutines or
Android. The composable then receives sections and fires events; nothing else.

---

## Package-level problems

### `gateway/` is a 20-file bin

Five distinct concerns are flat in one directory:

| Concern | Files |
|---|---|
| Session / link lifecycle | `BackendSession`, `BackendIdentity`, `BackendLaunchName`, `BackendTaskState`, `LinkRefresh`, `LinkWindow` |
| Remote run execution | `RemoteTaskRunner`, `RemoteRunPlanner`, `RemoteRunPlan`, `RemoteRunRequest`, `RemoteScreenState`, `ScreenAccess`, `RunBudget` |
| Push / wake | `FirebaseToken`, `HopaMessagingService`, `PushTokenFetch`, `WakeRequest`, `WakeRequests` |
| Sync | `CatalogUpdater`, `ChatSync`, `ChatSyncJson`, `ChatSyncReport`, `ProcessedTaskStore` |
| Task dedup | `ProcessedTaskStore` |

Rename `gateway/` → `link/` and give it subpackages:

```
link/
  session/   connection lifecycle
  remote/    remote run execution, task dedup
  push/      FCM + wake
  sync/      CatalogUpdater + ChatSync + ProcessedTaskStore
```

Why `link/` and not `backend/`: the app already has the `core/backend` module and
the `services/backend` server, and `core/backend` calls its client-facing package
`link`. A third package called `backend` makes an import
(`com.hopa.app.backend.…`) impossible to place at a glance.

### `gate/` and `gateway/` are one character apart

`gate/` = approval dialog. `gateway/` = backend server. Someone scanning the
package list will misread one as the other. `gate/` also holds a single file, so
merge `UiApprovalGateway` into `ui/` rather than creating another one-file
package.

### `knowledge/` is already renamed

Done in `edcc4c3b`: the Android package is `catalog/`, the source is
`AssetCatalogSource`, the updater is `CatalogUpdater`. What remains is only the
**move** of `CatalogUpdater` into `link/sync/`.

Do not reintroduce the word "knowledge" anywhere except the wire names:
`knowledge.v1.json`, `GET /v1/knowledge`, `knowledgeVersion`.

### `feature/sync/` is not a feature

`ChatSync`, `ChatSyncJson`, `ChatSyncReport` are background coordination code —
no UI, no Route, no Screen, no ViewModel. They belong in `link/sync/` alongside
`CatalogUpdater`, not inside `feature/`.

### `LaunchPairing.kt` at root level

`LaunchPairing` handles one specific deep-link intent. The root package is for
Android entry points (`Application`, `Activity`, top-level composable).
`LaunchPairing` belongs in `navigation/`.

### `di/RemoteRuns` is misplaced

`RemoteRuns` is a thin adapter bridging a `RemoteRunRequest` from the link to
`RunCoordinator`. It is not a DI wiring class. It belongs next to the coordinator.

### `tasks/` should fold into the run package

`ParallelRunner` and `TaskItem` manage multiple background goals running on hidden
displays — a variant of run coordination, not a separate domain.

The current top-level `run/` and the feature package `feature/runs/` differ by one
letter and mean different things (the coordinator vs the runs screen) — the same
problem as `gate/` vs `gateway/`. Fix it while moving: the coordinator package
becomes `runtime/`, and `feature/runs/` keeps its name.

```
runtime/
  RunCoordinator.kt
  RunGate.kt
  RunState.kt
  RemoteRuns.kt           ← was di/RemoteRuns.kt
  ParallelRunner.kt        ← was tasks/ParallelRunner.kt
  TaskItem.kt              ← was tasks/TaskItem.kt
```

---

## Feature-level problems

### Easy and Power modes are structured asymmetrically

`feature/power/` exists for the Power-mode home. Easy-mode screens have no
equivalent package — `EasyHistoryRoute`/`EasyHistoryScreen` live inside
`feature/conversations/`, and `HopaBottomBarEasy` lives inside `ui/component/`.

Create `feature/easy/` and move the Easy history route and screen there.
`HopaBottomBarEasy` is used by both Easy history and `ChatScreen`, so it is shared
chrome: leave it in `ui/component/`.

### `MemoryViewModel` manages both facts and skills

`SkillsRoute` borrows `MemoryViewModel` because facts and skills share
`MemoryUiState`. This is accidental coupling — adding a skill triggers a reload
of both facts and skills. A dedicated `SkillsViewModel` operating only on
`container.skills` removes the coupling and makes `feature/skills/` self-contained.

### `feature/settings/` is 45 files flat

Once `SettingsViewModel` is split, sub-ViewModels and their screens should live
in the matching subpackage, with shared rows/dividers in `settings/shared/`.

---

## Rules the new layout must keep

1. `feature/*` may depend on `runtime`, `link`, `catalog`, `ui`, `service` and the
   libraries — never on another `feature/*`, except `feature/shell`, which owns
   the navigation shell.
2. No package holds a single file. If it would, merge it into its parent (the
   same rule `core` follows).
3. Every move is `git mv`; the moves PR changes no behaviour.
4. Wire names never change: `knowledge.v1.json`, `/v1/knowledge`,
   `knowledgeVersion`, `/v1/gateway`.
5. The FCM entry in `AndroidManifest.xml` moves with `HopaMessagingService`.
   As of this writing the manifest points at `.backend.HopaMessagingService`,
   but the class lives in `gateway`, so the wake path is dead in every build
   since #52. The move fixes it to `.link.push.HopaMessagingService`.
6. `check-android-structure.py` gains a rule for the feature dependency direction
   once the layout lands.

## Tests and docs

The point of moving logic out of `ChatsSheet` and `SettingsViewModel` is that it
becomes testable. Each extraction adds unit tests for the new ViewModel or pure
function; a moves-only PR adds none and must keep the suite green.

After the moves, update `docs/design/architecture/apps-android.md` and the app
README so the pictures match the packages.

## Proposed structure

```
com.hopa.app/

HopaApp.kt
HopaApplication.kt
MainActivity.kt

navigation/
  HopaDestination.kt
  HopaNavHost.kt
  LaunchPairing.kt        ← was root level

di/
  AppContainer.kt
  Surfaces.kt
  SettingsModelPort.kt

service/                  ← unchanged

ui/                       ← unchanged
  component/
  theme/
  UiApprovalGateway.kt    ← was gate/UiApprovalGateway.kt

privacy/                  ← unchanged

share/                    ← unchanged

catalog/                  ← removed: the bundled source lives in :data

runtime/                  ← was run/ + tasks/ + di/RemoteRuns
  RunCoordinator.kt
  RunGate.kt
  RunState.kt
  RemoteRuns.kt
  ParallelRunner.kt
  TaskItem.kt

link/                     ← was gateway/, now with subpackages
  session/
    BackendSession.kt
    BackendIdentity.kt
    BackendLaunchName.kt
    BackendTaskState.kt
    LinkRefresh.kt
    LinkWindow.kt
  remote/
    RemoteTaskRunner.kt
    RemoteRunPlanner.kt
    RemoteRunPlan.kt
    RemoteRunRequest.kt
    RemoteScreenState.kt
    ScreenAccess.kt
    RunBudget.kt
    ProcessedTaskStore.kt
  push/
    FirebaseToken.kt
    HopaMessagingService.kt
    PushTokenFetch.kt
    WakeRequest.kt
    WakeRequests.kt
  sync/
    ChatSync.kt             ← was feature/sync/ChatSync.kt
    ChatSyncJson.kt         ← was feature/sync/ChatSyncJson.kt
    ChatSyncReport.kt       ← was feature/sync/ChatSyncReport.kt
    CatalogUpdater.kt       ← was gateway/CatalogUpdater.kt

feature/
  browser/
  capabilities/
  chat/
  conversations/            ← ChatsSheet, ConversationsViewModel only
  easy/                     ← new
    EasyHistoryRoute.kt     ← was conversations/EasyHistoryRoute.kt
    EasyHistoryScreen.kt    ← was conversations/EasyHistoryScreen.kt
  execution/
  history/
  launchpad/
  memory/                   ← facts only
  power/
  profiles/
  runs/
  settings/
    SettingsRoute.kt        ← top-level router only
    SettingsScreen.kt
    model/                  ← ModelSettingsViewModel + screen
    surface/                ← SurfaceSettingsViewModel + screen
    pairing/                ← PairingViewModel + backend + bridge screens
    diagnostics/            ← DiagnosticsViewModel + self-check screen
    notify/                 ← NotifyViewModel + screen
    shared/                 ← SettingsDivider, SettingsRow, shared UI
  shell/
  skills/                   ← SkillsViewModel independent from memory
  usage/
```

---

## Priority order

### PR 1 — moves and renames, no behaviour change

1. `gate/UiApprovalGateway.kt` → `ui/` (it was a one-file package)
2. `gateway/` → `link/` with `session`, `remote`, `push`, `sync` subpackages
3. `feature/sync/` → `link/sync/`
4. `LaunchPairing.kt` → `navigation/`
5. `di/RemoteRuns.kt` → `runtime/`
6. `tasks/` → `runtime/`; `run/` → `runtime/`
7. Create `feature/easy/` for the Easy history screens
8. Fix the FCM manifest entry while `HopaMessagingService` moves
9. Update the architecture docs

### PR 2 — the chat list and skills

10. Extract date grouping from `ChatsSheet` into a pure function; test it
11. Move the bridge sync out of `ChatsSheet` into `ConversationsViewModel`
12. `SkillsViewModel` independent from `MemoryViewModel`; drop skills from
    `MemoryUiState`
13. Unit tests for each extraction

### PR 3 — settings per screen

14. Extract the four concerns out of `SettingsViewModel` into focused classes
    first (model, pairing, surface, preferences); the ViewModel keeps its public
    API, so no screen changes.
15. Then turn each concern into its own ViewModel, one screen at a time, and
    change the screen signatures. This step needs a device smoke test.
16. Organise `feature/settings/` into the subpackages above
17. Unit tests for the extracted logic

### PR 4 — dependency injection

18. Decide narrow containers vs Hilt, in an ADR
19. Implement the winner; delete whatever wiring it replaces

### PR 5 — Gradle modules

20. `:platform:ui` with the theme and the shared Compose chrome — done
21. The plush drawables and `HopaMascot` moved into the library — done
22. Extract feature modules one at a time — `:feature:usage` is the first
23. Continue with `:feature:settings`, then the rest

### After the module split

24. Done: Compose BOM 2026.11.01 and Navigation 2.10.2, on the AGP 9.5 / Gradle
    9.6 / built-in Kotlin 2.4 toolchain. Navigation 3 was considered and not
    adopted: the typed routes on Nav2 cover the graph, and Nav3 would rewrite
    the shell without a product gain.
25. Done: one state holder per screen. Eleven routes that held their data in
    `remember` now collect one `UiState` from a `@HiltViewModel`; `remember` is
    left for dialogs, in-screen filters and text fields.
26. Done: `check-android-structure.py` fails when a feature imports another
    feature (with `execution -> settings` as the recorded exception) or imports
    the app module.
27. Done: `:screenshots` renders Settings, Activity and Runs through Robolectric
    and Roborazzi on the JVM; CI runs `verifyRoborazziDebug`.
28. Done: Hilt is the graph (ADR-0024 revision); the narrow interfaces are the
    boundaries and the seam for tests.
29. Done for the caches: the configuration cache is on and reused in CI (which
    halved the Android job), and the build cache was already on. Baseline
    profile is open: generating it needs a device or an emulator run, and this
    repository's release is a debug APK for a phone that is not connected. It
    stays listed here rather than as a module that produces no profile.

The module split is complete. `app` keeps the composition root and platform
glue: `di` (the Hilt graph), `navigation`, `service`, the shell, and the
`link`/`runtime` orchestration that owns the container. Everything a person
navigates to is a feature or core module.
