# 11. Phase 6 â€” Product and UI (4â€“6 weeks)

- [ ] Chat with streaming and cancel
- [ ] Task progress: steps, current action, live screen thumbnail
- [ ] Floating capsule or notification when backgrounded
- [ ] Takeover: pause, user acts, hand back
- [ ] Approval sheet with amount, merchant, consequence
- [ ] Memory view: runs, learned notes, skills, delete
- [x] Settings: model, key, network, a11y status, sandbox, retention (evidence: app Settings tab; verified on the emulator; a11y toggle disabled until ACL; network toggle now gates web.navigate)
- [ ] Onboarding: what it can and cannot do, permissions, safety
- [ ] Empty, loading and error states
- [ ] HOPA's own accessibility: screen reader labels, contrast, font scale
- [ ] i18n: English + Chinese minimum
- [ ] Dark mode
- [ ] App icon and splash
- [x] Signing configuration (evidence: tools/scripts/sign-app.ps1 + docs/guides/build-and-sign.md; debug profile only, release profile pending)
- [ ] Opt-in crash reporting
- [ ] E2E UI tests
- [ ] Cold start < 2 s
- [ ] 30-minute task battery profile
- [ ] HAP size budget
- [ ] Memory footprint budget
- [ ] Network usage budget
- [ ] Error messages localized
- [x] `docs/product/ux.md` (evidence: docs/product/ux.md)
- [ ] 10 beta users, feedback log

### 11.1 Missing product features

- [ ] Scheduled tasks (time-based) with a visible schedule
- [ ] Triggers (event-based) with explicit consent
- [ ] Task templates and shortcuts
- [ ] History and search across runs
- [ ] Read-only replay of a past run
- [ ] Voice input, or a recorded decision to defer it
- [ ] Share target: receive text, image or file from other apps
- [x] Quick action or home-screen widget (long-press shortcuts: Ask HOPA, Last run; verified on the Pura 90) (evidence: apps/harmony/phone/src/main/module.json5, apps/harmony/phone/src/main/resources/base/profile/shortcuts.json)
- [ ] Completion notification
- [ ] Cost and latency display per run
- [ ] Undo where the platform allows it
- [ ] Feedback and â€œreport a problemâ€ with redacted logs
- [ ] Export run history
- [ ] Multi-device and PC companion view
- [ ] Task queue and concurrency policy (one active task by default)
- [ ] Recurring schedules
- [ ] Missed schedule while the device was off
- [ ] Background execution limits for scheduled tasks
- [ ] DST and time-zone changes for schedules
- [ ] CAPTCHA handover tested
- [ ] 2FA handover tested
- [ ] Onboarding states plainly that HOPA drives the visible screen and cannot work in the background

### 11.2 Exit criteria (M6 part 1)

- [ ] A new user can install and complete one task without help
- [ ] No P0 bugs open
- [ ] Every permission has an explanation screen

### 11.3 Trust UX

- [ ] â€œWhy did HOPA do that?â€ explanation for every step
- [ ] Timeline with step, action, result and screenshot
- [ ] Pause and stop always reachable in one tap
- [ ] Approval sheet is screen-reader accessible and respects font scale
- [ ] Error recovery offers retry, edit, hand over and abort
- [ ] Cost and token usage visible per run and per day
- [ ] Model switch and fallback state visible
- [ ] Offline banner with a clear next step
- [ ] Notification actions: stop and open
- [ ] Lock-screen notification hides task details
- [ ] Quick Settings tile or shortcut for stop
- [ ] â€œWhat HOPA cannot doâ€ page in the app
- [ ] Feedback entry with a redacted diagnostic bundle
- [ ] First-run safety walkthrough skippable and replayable

---

