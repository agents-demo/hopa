# ADR-0027 — Windows is a full semantic-parity client

- Status: accepted
- Date: 2026-11-24
- Owners: Windows lead
- Relates to: ADR-0020 (Android is the active client), ADR-0021 (Windows client
  stack), ADR-0024 (Windows device identity and approval), P5–P6 of
  `docs/project/plan/windows/README.md`

## Context

The Windows plan was written as a **desktop leg**, not a second product. It named
three jobs (UI Automation, long forms/signature, phone approval) and listed
profiles, memory, usage, launchpad, self-check, browser and the notifier as
non-goals. `docs/project/plan/windows/parity.md` marked roughly twenty Android
screens `out` for that reason.

The product goal has changed: Windows should reach **total parity with Android**.
Keeping the desktop-leg framing would make the work look out of scope, and the
existing `out` rows are not a plan. The Android app remains the reference
client; the question is how much of it has a desktop equivalent, not whether
the Windows app is allowed to grow.

## Decision

- **Windows is a full client with semantic parity against Android.** Parity
  means the same job and the same outcome, with a desktop-native surface. It
  does **not** mean a literal 1:1 copy of phone screens.
- **Android remains the reference.** Every parity row names its Android screen
  and source. The status vocabulary becomes `have`, `adapt`, `new`, or
  `not-applicable`. `not-applicable` needs a platform reason; a product
  preference is not enough.
- **The shared brain is unchanged.** The loop, gate, contracts, records and
  approval provenance still come from `core/`; the sidecar remains the Windows
  engine host. Parity is not a second implementation.
- **Data and protocol come before screens.** Platform-neutral stores
  (memory, skills, profiles, recipes, usage, history) move out of Android-only
  modules or get a documented Windows implementation. The sidecar protocol
  grows additively; a UI screen is not started until its data path exists.
- **Desktop adaptations are explicit.** The plan defines the equivalent for
  notifier, accessibility, profiles and the Android "Act → My computer" driver
  relationship. None of them becomes a silent `out`.
- **The parity plan is `docs/project/plan/windows/total-parity.md`.** It carries
  the phases, checkboxes and evidence rules. `parity.md` is the screen-by-screen
  matrix that feeds it.
- **P5 and P6 stay in the existing plan.** Takeover/signature and the signed MSI
  are part of parity; they are not replaced by this ADR.

## Consequences

- The Windows work is larger than the P0–P6 plan implied. Profiles, memory,
  usage, skills, recipes, launchpad, browser, notifications, settings
  navigation and the desktop adaptations become planned work.
- Android `stores` is no longer an Android-only module by default: pure data
  and contract pieces should be extracted to a platform-neutral home, or the
  Windows sidecar must implement the same contract. The choice is made per
  store in W8, not by copying code.
- The sidecar protocol gains families for the new data. Additive message types
  keep v1 hosts working; breaking shape changes still bump the version.
- The real-desktop CI job becomes a parity release gate, not an optional check.
- A change to a shared Android feature now has a Windows parity question. The
  matrix must say `have`, `adapt`, `new`, or why it is `not-applicable`.

## Alternatives considered

- **Keep the desktop-leg plan.** Rejected by the new product goal. It would
  leave most of Android permanently out of scope.
- **Literal screen-for-screen parity.** Rejected. A phone notifier, an Android
  accessibility service and an adb screen driver do not become good desktop
  features by copying their screens. The plan names a desktop equivalent
  instead.
- **Build the UI first and fill the data later.** Rejected. It produces empty
  screens and hides the real dependency: shared stores and sidecar messages.
- **Duplicate every Android store in C#.** Rejected. Two implementations drift
  and break the one-brain rule. Prefer a platform-neutral contract with one
  Windows file-backed adapter.
- **Treat every Android screen as mandatory.** Rejected. A row may be
  `not-applicable` when the platform has no honest equivalent, but the reason
  must be written down and reviewed.
