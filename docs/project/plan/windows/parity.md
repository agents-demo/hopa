# Windows parity checklist

The reference is the **Android app**. Every row names an Android screen and its
source file; there is no other reference client. Status is one of `have`, `todo`,
`out` (deliberately not on Windows), or `P4`/`P5` (scheduled).

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
| Runs | `feature/runs/RunsScreen.kt` | `StepsWindow` (steps, classification, chain) | have |
| Approval sheet | `ui/component/ApprovalSheet.kt` | `ApprovalWindow` (title, amount, merchant, consequence) | have |
| Settings hub with search | `feature/settings/SettingsScreen.kt` | `SettingsWindow` | out (three fields fit on one dialog) |
| Settings — Answers (model, key, vision) | `feature/settings/SettingsModelScreen.kt` | model provider, endpoint, key | have; vision is `out` until the host sends frames |
| Settings — My computer (bridge) | `feature/settings/SettingsBridgeScreen.kt` | bridge address and token | have |
| Settings — Tone and length | `feature/settings/SettingsCharacterScreen.kt` | tone | have |
| Settings — Run history | `feature/settings/SettingsHistoryScreen.kt` | runs window | have |
| Settings — Alerts | `feature/settings/SettingsNotificationsScreen.kt` | none | out (the phone owns the notifier) |
| Settings — What left your phone | `feature/settings/SettingsPrivacyScreen.kt` | none | out |
| Settings — Saved repetitions | `feature/settings/SettingsRecipesScreen.kt` | none | out |
| Settings — Running apps | `feature/settings/SettingsScreenAccessScreen.kt` | none in v0; UI Automation reports the foreground app in `observe` | out |
| About | `feature/settings/AboutScreen.kt` | About row in settings | have |
| Self check | `feature/settings/SelfCheckScreen.kt` | none | out |
| Accessibility setup | `feature/settings/AccessibilityScreen.kt` | none: the PC uses UI Automation, not an accessibility service | out |
| Memory | `feature/memory/MemoryScreen.kt` | none | out |
| Usage | `feature/usage/UsageScreen.kt` | none | out |
| Profiles | `feature/profiles/ProfilesScreen.kt` | none: the desktop has one shape | out |
| Capabilities | `feature/capabilities/CapabilitiesScreen.kt` | none in v0; the bridge line on the rail carries the status | out |
| Launchpad | `feature/launchpad/LaunchpadScreen.kt` | none: UIA launches by name, from the catalog | out |
| Device | `feature/device/DeviceScreen.kt` | none: this PC *is* the device | out |
| Browser | `feature/browser/BrowserScreen.kt` | none in v0 | out |
| Notifier | `service/Notifier.kt` | none: the phone owns the event surface | out |
| Approval on the phone | `ui/component/ApprovalSheet.kt` | request pushed to the phone, answer returned | P4 |
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
one exception is approval, which is `P4` because the PC must be able to ask the
phone when the action runs on the desktop.

## Prompt context the PC sends

The sidecar passes `platform = "windows"` and the catalog's Windows app list to
the shared loop, so the model launches by a package the PC can actually open.
`phoneAccess` is true only when a host is attached; headless passes false. The
catalog still cannot prove an app is installed, so the prompt says a launch may
fail, and the adapter reports the real foreground afterwards.
