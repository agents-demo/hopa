# Windows total parity plan (W7–W11)

Status: **W7–W8 done. W9 in progress; W10–W11 planned.** The product decision is
[ADR-0027](../../../design/decisions/0027-windows-semantic-parity.md): Windows is a
full client with **semantic** parity against Android. Android remains the
reference; the screen-by-screen matrix is [parity.md](parity.md).

A box is ticked only when the behaviour exists **and** an artifact proves it.
Every tick carries `(evidence: ...)`.

## 1. What parity means

| Layer | Parity means | Not |
|---|---|---|
| Behaviour | the same gate, records, approvals, target choice and honest failures | a second engine |
| Data | memory, skills, profiles, recipes, usage, history and notifications have the same contracts | a C# copy of every Android store |
| Surface | every Android job has a Windows screen, adapted to the desktop | a literal phone screen |

Status in `parity.md`: `have`, `adapt`, `new`, `not-applicable`. A
`not-applicable` row must name a platform reason; "the phone does it better" is
no longer sufficient after ADR-0027.

## 2. Scope decisions

These are settled for planning; W7 records them in `parity.md`.

- **Notifier** → Windows toast + notification center. The PC owns its own event
  surface; it does not proxy the phone's notifications.
- **Accessibility setup** → UIA/elevation/uiAccess readiness. The Windows
  equivalent is a prerequisite screen, not an Android accessibility service.
- **Profiles** → Windows workspaces/modes over the same profile contract. The
  user can switch context; the visual shape is desktop-native.
- **Act → My computer** → target chooser: this PC through UIA, or hand the task
  to the phone through the gateway. The PC does not mirror the phone screen.
- **Browser** → embedded WebView2 pane, with the shared browser contract; link
  opening remains the fallback.
- **Vision** → send frames when the host enables it and the selected model
  accepts images. The parity row is not `have` until a frame round-trip works.
- **Takeover/signature** → P5 in the existing plan, still a parity row.

## 3. Phases

### W7. Parity contract — done

Make the scope reviewable and stop using `out` as a silent product decision.

- [x] ADR-0027 is accepted and linked from the Windows plan. (evidence: `docs/design/decisions/0027-windows-semantic-parity.md`)
- [x] `parity.md` uses `have`/`adapt`/`new`/`not-applicable` for every Android screen and every new desktop row. (evidence: `docs/project/plan/windows/parity.md`)
- [x] Every `not-applicable` row names a platform reason. (evidence: `parity.md` has no `not-applicable` rows; every Android row has a desktop equivalent)
- [x] The settings hub, profiles/workspaces, notifier, accessibility, browser and phone-handoff decisions are recorded. (evidence: `parity.md`; this file, "Scope decisions")
- [x] The plan's `P0–P6` README no longer calls Windows a desktop leg or lists parity features as non-goals. (evidence: `docs/project/plan/windows/README.md`)

Gate: a reader can tell, for every Android screen, whether Windows has it,
adapts it, still needs it, or cannot have it — and why.

### W8. Shared data and protocol — done

Build the data path before the screens.

- [x] Audit `apps/android/stores` and the feature data used by memory, skills,
  profiles, recipes, usage and history; classify each as platform-neutral,
  Android-only, or already shared. (evidence: the table below)
- [x] Move or expose the platform-neutral stores through a shared JVM contract;
  keep Android's platform implementation and add a Windows file-backed adapter.
  (evidence: `apps/windows/sidecar/settings.gradle.kts` includes `:stores`;
  `MemoryFileStore`, `SkillFileStore`; the profile catalogue moved to
  `apps/android/stores/Profile.kt`)
- [x] Add the `memory.*` and `skills.*` sidecar families and their round-trip
  tests. (evidence: `MemoryHandler`, `SkillHandler`, `MemoryFileStoreTest`,
  `SkillFileStoreTest`, `DataProtocolTest`)
- [x] Launchpad reads the existing `device.apps` Start-menu list; notifications
  and self check are host surfaces (W9), not data stores. (evidence: this file;
  W9 tasks)
- [x] Add the `history.*`, `usage.*`, `recipes.*`, `profiles.*` and
  `capabilities.*` families and their tests. (evidence: `HistoryHandler`,
  `UsageHandler`, `RecipesHandler`, `ProfilesHandler`, `CapabilitiesHandler`,
  `RecordStatsTest`, `CapabilitiesCollectorTest`, `DataProtocolTest`)
- [x] Add host methods and a real-process integration test for memory, skills,
  history, usage, recipes, profiles and capabilities. (evidence:
  `EngineHostClient.Memory.cs`, `EngineHostClient.Skills.cs`,
  `EngineHostClient.History.cs`, `EngineHostClient.Usage.cs`,
  `EngineHostClient.Recipes.cs`, `EngineHostClient.Profiles.cs`,
  `EngineHostClient.Capabilities.cs`, `EngineDataTests`)
- [x] Keep v1 hosts working for the existing messages; the new families are
  additive and documented. (evidence: `protocol.md`; sidecar suite)

### W8 audit

| Data | Where it lives | Platform | Windows path |
|---|---|---|---|
| memory facts | `apps/android/stores/MemoryStore.kt`; Android impl `data/DbMemoryStore.kt` | JVM interface + Android Room | `sidecar/store/MemoryFileStore.kt` |
| skills | `apps/android/stores/Skill.kt`, `SkillStore.kt`; Android impl `data/DbSkillStore.kt` | JVM interface + Android Room | `sidecar/store/SkillFileStore.kt` |
| settings/profile | `apps/android/stores/AppSettings.kt`, `SettingsRepository.kt` | JVM contract; Android DataStore | `RuntimeConfig` + C# `SettingsStore`; profile field/UI next |
| conversations | `apps/android/stores/ConversationStore.kt`; Android impl `data/DbConversationStore.kt` | JVM interface + Android Room | `sidecar/store/ChatStore.kt` |
| run history / usage | `core/runlog`; Android `data/DbRunHistory.kt` | shared core + Android Room | `sidecar/store/RecordStore.kt` |
| recipes | `core/agent/recipe/RecipeStore.kt` | shared JVM | sidecar already depends on `agent`; expose commands |
| profiles | `AppSettings.profile` over `SettingsRepository` | JVM contract | setting field + W9 workspaces UI |
| notifications | Android `app/service/Notifier.kt` | Android-only | Windows tray/toast; no shared store |
| capabilities / launchpad | `core/catalog`, Android feature modules | shared data + Android UI | catalog + Windows app catalog |

Gate: the Windows sidecar can list, read and mutate each parity data family
without Android code or a second store implementation.

### W9. Information surfaces — in progress

The settings hub and the screens that read the shared data.

- [x] A settings hub with search and subpages replaces the single settings
  dialog. (evidence: `SettingsWindow.xaml`; the DevTools settings shot)
- [ ] Activity/history timeline and run history. (evidence: screenshot + data
  test)
- [x] Memory screen. (evidence: `MemoryPage`; `EngineDataTests`)
- [x] Skills screen. (evidence: `SkillsPage`; `EngineDataTests`)
- [x] Profiles/workspaces screen. (evidence: `ProfilesPage`; `EngineDataTests`)
- [x] Usage screen. (evidence: `UsagePage`; `RecordStatsTest`)
- [x] Recipes screen. (evidence: `RecipesPage`; `EngineDataTests`)
- [x] Capabilities screen. (evidence: `CapabilitiesPage`; `EngineDataTests`)
- [ ] Privacy: "what left this PC". (evidence: screenshot + record sample)
- [ ] Self check. (evidence: screenshot + check transcript)
- [ ] Notification center and toast history. (evidence: screenshot + delivery test)
- [ ] Launchpad over the shared app catalog. (evidence: screenshot + launch test)
- [ ] About and the existing settings values are integrated into the hub.
  (evidence: screenshot)

Gate: every information row in `parity.md` has a working screen fed by real
data, not a fixture.

### W10. Action parity — planned

The screens that change what HOPA does.

- [ ] Easy/power modes. (evidence: screenshot + mode test)
- [ ] Run preferences and setup. (evidence: screenshot + persisted settings)
- [ ] Act hub with the this-PC / phone-handoff target chooser. (evidence:
  screenshot + both paths)
- [ ] How HOPA acts: the tier/policy explanation. (evidence: screenshot +
  selector test)
- [ ] Browser pane with WebView2 and the shared browser contract. (evidence:
  screenshot + navigation test)
- [ ] Takeover/signature P5. (evidence: form transcript + verified postcondition)
- [ ] Vision frame round-trip when a model accepts images. (evidence: protocol
  test + one real frame)
- [ ] Phone handoff semantics: a task sent from the PC is owned by the phone;
  the PC does not mirror its screen. (evidence: gateway transcript + record)

Gate: an Android action screen has a Windows counterpart that produces the same
record and the same gate decision.

### W11. Parity evidence — planned

Prove the matrix instead of asserting it.

- [ ] A screenshot for every `have`/`adapt`/`new` surface, Android and Windows
  side by side in one artifact. (evidence: `out/windows-parity` artifact)
- [ ] The desktop CI job runs the parity smoke: launch, observe, approve,
  settings, memory/skills/usage read, notification, screenshot. (evidence:
  `windows-desktop.yml` run)
- [ ] Contract tests cover every sidecar family from W8. (evidence: test log)
- [ ] No screen text or secrets in logs, screenshots or crash dumps. (evidence:
  grep + review)
- [ ] The signed MSI installs on a clean VM and passes the same smoke. (evidence:
  MSI hash + VM transcript)
- [ ] `parity.md` has no planned row without an artifact or an explicit
  `not-applicable` reason. (evidence: matrix review)

Gate: a reviewer can compare the Android and Windows clients screen by screen
and every difference is a written decision.

## 4. Order and dependencies

```
W7 parity contract
  └─ W8 shared data + protocol
       ├─ W9 information surfaces
       └─ W10 action surfaces
            └─ W11 evidence + release gate
```

W9 and W10 may interleave after W8, but neither starts with a UI-only fixture.
P5 (takeover/signature) sits in W10; P6 (MSI) closes W11.

## 5. Risks

| Risk | Mitigation |
|---|---|
| "Parity" becomes a literal copy of phone screens | semantic table in §1; `adapt` is a first-class status |
| Shared stores split into two implementations | W8 audit chooses one contract per store; Windows adapter owns only persistence |
| Protocol grows without tests | round-trip test per family; v1 compatibility test |
| The UI ships empty shells | W8 gate before W9/W10 |
| Desktop-only jobs are missed | real-desktop CI is the W11 gate |
| Scope hides the existing P5/P6 work | P5 is W10, P6 is W11; both stay in the main plan |
