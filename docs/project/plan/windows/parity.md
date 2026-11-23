# Windows parity checklist

The reference is the **Android app**. Every row names an Android screen and its
source file; there is no other reference client. Status is one of `have`, `todo`,
`out` (deliberately not on Windows), or `P5` (scheduled).

| Android screen | Source | Windows equivalent | Status |
|---|---|---|---|
| Chat (top-level tab) | `apps/android/app/src/main/kotlin/com/hopa/app/feature/chat/ChatScreen.kt` | chat column in `MainWindow` | have |
| Message bubble | `feature/chat/component/MessageBubble.kt` | `MessageTemplate` | have |
| Composer | `feature/chat/component/Composer.kt` | composer pill, Enter = newline, Ctrl+Enter = send | have |
| Empty state | `feature/chat/component/ChatEmptyState.kt` | empty state with the mark | have |
| Attachment preview | `feature/chat/component/AttachmentPreview.kt` | pending attachment bar | have |
| Conversation list | `feature/conversations/ChatsSheet.kt` | sidebar list with pin, archive, rename, export, delete | have |
| Easy history | `feature/conversations/EasyHistoryScreen.kt` | none | out (no profiles on the PC) |
| Activity | `feature/activity/ActivityScreen.kt` | run rail plus the runs window | have |
| Runs | `feature/runs/RunsScreen.kt` | `RunDetailsWindow` (steps, classification, chain) | have |
| Approval sheet | `ui/component/ApprovalSheet.kt` | `ApprovalWindow` (title, amount, merchant, consequence) | have |
| Settings hub with search | `feature/settings/SettingsScreen.kt` | `SettingsWindow` | out (three fields fit on one dialog) |
| Settings — Answers (model, key, vision) | `feature/settings/SettingsModelScreen.kt` | model provider, endpoint, key | have; vision is `out` until the host sends frames |
| Settings — My computer (pairing) | `feature/runningapps/ComputerScreen.kt` | backend pairing and bridge address | have (token entry) |
| Settings — Tone and length | `feature/settings/SettingsCharacterScreen.kt` | tone | have |
| Settings — Run history | `feature/settings/SettingsHistoryScreen.kt` | runs window | have |
| Settings — Alerts | `feature/settings/SettingsNotificationsScreen.kt` | none | out (the phone owns the notifier) |
| Settings — What left your phone | `feature/settings/SettingsPrivacyScreen.kt` | none | out |
| Settings — Saved repetitions | `feature/settings/SettingsRecipesScreen.kt` | none | out |
| Act hub (where HOPA works) | `feature/runningapps/RunningAppsScreen.kt` | none in v0; the window already picks a target per action | out |
| Computer / "My computer" | `feature/runningapps/ComputerScreen.kt` | none: the PC *is* the device (see the note below) | out |
| How HOPA acts | `feature/runningapps/HowHopaActsScreen.kt` | out of scope for v0; the rail states what ran | out |
| Run preferences / setup | `feature/runningapps/RunPrefsScreen.kt`, `feature/runningapps/RunSetupScreen.kt` | none in v0 | out |
| About | `feature/settings/AboutScreen.kt` | About row in settings | have |
| Self check | `feature/settings/SelfCheckScreen.kt` | none | out |
| Accessibility setup | `feature/settings/AccessibilityScreen.kt` | none: the PC uses UI Automation, not an accessibility service | out |
| Memory | `feature/memory/MemoryScreen.kt` | none | out |
| Skills | `feature/memory/SkillsScreen.kt` | none | out |
| Usage | `feature/usage/UsageScreen.kt` | none | out |
| Profiles | `feature/profiles/ProfilesScreen.kt` | none: the desktop has one shape | out |
| Capabilities | `feature/capabilities/CapabilitiesScreen.kt` | none in v0; the bridge line on the rail carries the status | out |
| Launchpad | `feature/launchpad/LaunchpadScreen.kt` | none: UIA launches by name, from the catalog | out |
| Device | `feature/runningapps/ComputerScreen.kt` | none: this PC *is* the device | out |
| Browser | `feature/browser/BrowserScreen.kt` | none in v0 | out |
| Notifier | `service/Notifier.kt` | none: the phone owns the event surface | out |
| Approval on the phone | `ui/component/ApprovalSheet.kt` | request pushed to the phone, answer returned | have |
| Takeover / signature | none yet | pause, hand over, resume, verify | P5 |

## Token check

The WPF palette is the Android palette, not a lookalike:

| Token | Android | Windows |
|---|---|---|
| background | `#F7F4EE` | `#F7F4EE` |
| surface | `#FFFFFF` | `#FFFFFF` |
| sidebar | `#F3EFE7` | `#F3EFE7` |
| muted | `#F1ECE3` | `#F1ECE3` |
| ink | `#1C1B18` | `#1C1B18` |
| hint | `#9A9488` | `#9A9488` |
| primary | `#0A59F7` | `#0A59F7` |
| accent | `#E8703A` | `#E8703A` |
| danger | `#C0392B` | `#C0392B` |
| divider | `#E9E4DA` | `#E9E4DA` |

Body sizes follow `HopaType`: 15, 13.5, 11, with the answer at 13.5.

## What "out" means

A row marked `out` is a deliberate product decision, not a gap: the phone is where
those features belong, and duplicating them would create a second product. The
one exception is approval, which is `have`: the PC can ask the phone when the
action runs on the desktop (P4).

## The two meanings of "computer"

Android's *Act → My computer* and Windows P4 are **not** the same relationship.
In Act, the computer is an adb **driver for the phone's screen**: the phone still
chooses what happens, and the computer is never a silent fallback
(`docs/guides/android/run-modes.md`, `feature/runningapps/ActMode.kt`). In P4 the
Windows client acts on its **own UIA desktop** and asks the phone only to approve
the action (ADR-0024). Those rows stay `out` rather than `have`: a Windows screen
mirroring the driver mode would imply the wrong owner of the action. What the two
sides share is the backend gateway, not the device role.

## Prompt context the PC sends

The sidecar passes `platform = "windows"` and the catalog's Windows app list to
the shared loop, so the model launches by a package the PC can actually open.
`phoneAccess` is true only when a host is attached; headless passes false. The
catalog still cannot prove an app is installed, so the prompt says a launch may
fail, and the adapter reports the real foreground afterwards.
