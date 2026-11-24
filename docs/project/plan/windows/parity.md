# Windows parity matrix

The reference is the **Android app**. Every row names an Android screen and its
source file. Status is one of:

| Status | Meaning |
|---|---|
| `have` | the Windows behaviour exists and an artifact proves it |
| `adapt` | the same job exists in a desktop-native form; planned or in progress |
| `new` | no direct Android screen, but parity needs the surface; planned |
| `not-applicable` | the platform cannot honestly provide the job; the reason is written down |

This matrix follows [ADR-0027](../../../design/decisions/0027-windows-semantic-parity.md).
It is not a literal screen copy: the "Windows equivalent" column names the
desktop form. The phase plan is [total-parity.md](total-parity.md).

## Foundation

| Android screen | Source | Windows equivalent | Status |
|---|---|---|---|
| Chat (top-level tab) | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/ChatScreen.kt` | chat column in `MainWindow` | have |
| Message bubble | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/component/MessageBubble.kt` | `MessageBubble` in the chat pane | have |
| Composer | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/component/Composer.kt` | composer pill; Enter sends, Shift+Enter is a newline | have |
| Empty state | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/component/ChatEmptyState.kt` | empty state with the mark | have |
| Attachment preview | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/component/AttachmentPreview.kt` | pending attachment bar | have |
| Conversation list | `apps/android/feature/conversations/src/main/kotlin/com/hopa/feature/conversations/ChatsSheet.kt` | sidebar with pin, archive, rename, export, delete | have |
| Vision attachment | `apps/android/feature/chat/src/main/kotlin/com/hopa/feature/chat/component/Composer.kt` | a frame can ride with a model call; the host has no frame path yet | new |

## Execution

| Android screen | Source | Windows equivalent | Status |
|---|---|---|---|
| Activity | `apps/android/feature/history/src/main/kotlin/com/hopa/feature/history/ActivityScreen.kt` | run rail plus the runs window | have |
| Runs | `apps/android/feature/runs/src/main/kotlin/com/hopa/feature/runs/RunsScreen.kt` | `RunDetailsWindow` (steps, classification, chain) | have |
| Approval sheet | `apps/android/platform/ui/src/main/kotlin/com/hopa/ui/component/ApprovalSheet.kt` | `ApprovalWindow` (title, amount, merchant, consequence) | have |
| Approval on the phone | `apps/android/platform/ui/src/main/kotlin/com/hopa/ui/component/ApprovalSheet.kt` | request pushed to the phone, answer returned | have |
| History / activity timeline | `apps/android/feature/history/src/main/kotlin/com/hopa/feature/history/HistoryScreen.kt` | a combined conversation + run timeline | adapt |
| Easy history | `apps/android/feature/easy/src/main/kotlin/com/hopa/feature/easy/EasyHistoryScreen.kt` | mode/workspace history in the same timeline | adapt |
| Easy mode | `apps/android/feature/easy/src/main/kotlin/com/hopa/feature/easy/EasyHistoryScreen.kt` | a desktop "Easy" mode: fewer controls, guided target | new |
| Power mode | `apps/android/feature/power/src/main/kotlin/com/hopa/feature/power/PowerHomeScreen.kt` | a desktop "Power" mode: runs, preferences, raw tiers | new |
| Act hub | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/RunningAppsScreen.kt` | target chooser: this PC through UIA, or hand off to the phone | adapt |
| Computer / "My computer" | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/ComputerScreen.kt` | phone handoff over the gateway; the PC does not mirror the phone screen | adapt |
| How HOPA acts | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/HowHopaActsScreen.kt` | tier/policy explanation inside the run rail | new |
| Run preferences / setup | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/RunPrefsScreen.kt`, `RunSetupScreen.kt` | saved target and tier preferences | new |
| Device | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/ComputerScreen.kt` | this PC is the device; the phone is a peer target | adapt |
| Takeover / signature | none yet | pause, hand over, resume, verify | new (P5) |
| Launchpad | `apps/android/feature/launchpad/src/main/kotlin/com/hopa/feature/launchpad/LaunchpadScreen.kt` | Start-menu catalog with launch and stop | new |
| Browser | `apps/android/feature/browser/src/main/kotlin/com/hopa/feature/browser/BrowserScreen.kt` | WebView2 pane with link-out fallback; engine `web.navigate/read/click/type` drive the same window | have |
| Notifier | `apps/android/app/src/main/kotlin/com/hopa/app/service/Notifier.kt` | Windows toast + notification center | adapt |

## Settings and information

| Android screen | Source | Windows equivalent | Status |
|---|---|---|---|
| Settings hub with search | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/SettingsScreen.kt` | navigation hub with search and subpages | new |
| Settings — Answers (model, key, vision) | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/SettingsModelScreen.kt` | model provider, endpoint, key | have; vision is new |
| Settings — My computer (pairing) | `apps/android/feature/execution/src/main/kotlin/com/hopa/feature/execution/ComputerScreen.kt` | backend pairing and bridge address | have |
| Settings — Tone and length | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/PreferencesSettings.kt` | tone; length joins the Answers subpage | have |
| Settings — Run history | `apps/android/feature/history/src/main/kotlin/com/hopa/feature/history/HistoryScreen.kt` | runs window | have |
| Settings — Alerts | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/SettingsNotificationsScreen.kt` | Windows notification preferences + history | adapt |
| Settings — What left this phone | `apps/android/app/src/main/kotlin/com/hopa/app/feature/settings/SettingsPrivacyScreen.kt` | "What left this PC" and the record export | adapt |
| Settings — Saved repetitions | `apps/android/feature/history/src/main/kotlin/com/hopa/feature/history/RecipesScreen.kt` | recipes stored through the shared contract | new |
| Settings — Profiles | `apps/android/feature/profiles/src/main/kotlin/com/hopa/feature/profiles/ProfilesScreen.kt` | workspaces over the same profile contract | adapt |
| Settings — Memory | `apps/android/feature/memory/src/main/kotlin/com/hopa/feature/memory/MemoryScreen.kt` | memory list, add, edit, forget | new |
| Settings — Skills | `apps/android/feature/skills/src/main/kotlin/com/hopa/feature/skills/SkillsScreen.kt` | skill list and enable/disable | new |
| Settings — Usage | `apps/android/feature/usage/src/main/kotlin/com/hopa/feature/usage/UsageScreen.kt` | usage totals from `core/runlog` | new |
| Settings — Capabilities | `apps/android/feature/capabilities/src/main/kotlin/com/hopa/feature/capabilities/CapabilitiesScreen.kt` | UIA, bridge, gateway and model probe | new |
| Settings — Self check | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/SelfCheckScreen.kt` | sidecar, device, bridge and credential checks | new |
| Settings — Accessibility setup | `apps/android/feature/settings/src/main/kotlin/com/hopa/feature/settings/AccessibilityScreen.kt` | UIA/elevation/uiAccess readiness | adapt |
| About | `apps/android/app/src/main/kotlin/com/hopa/app/feature/settings/AboutScreen.kt` | About subpage in the hub | have |

## Run preferences

| Preference | Android | Windows | Status |
|---|---|---|---|
| Step source | `auto` / `model` / `graph`, with a graph catalogue | `auto` / `model` only; Windows has no graph catalogue | not-applicable for `graph`; auto and model are the model/recipe/command order |
| Cloud fallback | on-device model falls back to the API with consent | the Windows model is already the configured API provider; there is no on-device model to fall back from | not-applicable |
| Replay | stored recipe before the model | same, through the shared `TurnRunner` | have |
| Instant commands | canonical launch/back/home/scroll/wait | same, through `IntentClassifier` | have |
| Plan-first | plan, approve, resend | same, with `PlanWindow` | have |
| Vision | screenshot with the model call | wired through `TurnContext.vision`; a real image-model round-trip is still pending | adapt |

## Cross-cutting

| Area | Android | Windows | Status |
|---|---|---|---|
| Palette and type | `HopaType`, `HopaTheme` | shared WPF tokens in `Themes/Controls.xaml` | have |
| Gate and records | `core/agent`, `core/runlog` | sidecar uses the same modules | have |
| Approval provenance | `Approver.kt` | `approver.device` in the record | have |
| Protocol | bridge/gateway v1 | NDJSON v1 + additive parity families | adapt |
| Callback privacy | no screen text in logs | same rule; screenshots and crash dumps reviewed | have |
