# 9. Phase 4 â€” Capabilities (6â€“10 weeks, parallel with Phase 3)

### 9.1 Accessibility (the product)

- [ ] Verify the exact import and signature against the API 26 SDK
- [ ] Declare the extension in `module.json5` behind a build flag
- [ ] Confirm the week-1 ACL ticket is still open and escalate before Phase 4 starts
- [ ] `onConnect` marks availability
- [ ] `onAccessibilityEvent` converts the active window into `Observation`
- [ ] Read node `id`, `text`, `type`, `bounds`, `clickable`, `enabled`
- [ ] Tap by node ref
- [ ] Type text into a focused node
- [ ] Swipe and scroll
- [ ] Global back and home
- [ ] Foreground-only guard: define and enforce when HOPA may drive
- [ ] User consent screen and live status indicator
- [ ] Tests on Settings, Clock, Calendar
- [ ] Tests on 5 third-party apps
- [ ] Empty-tree detection and unsupported-app message
- [ ] OCR fallback for missing text
- [ ] Vision fallback for custom-drawn UIs
- [ ] `CAPTURE_SCREEN` request and per-session consent
- [ ] Screenshot redaction (status bar, notifications)
- [ ] Observe latency < 300 ms
- [ ] Accessibility-event throttling and debounce (no event flood)
- [ ] Stale-ref invalidation on window or tree change; never tap a stale ref
- [ ] Gesture-conflict policy with the user and with system gestures
- [x] `docs/guides/device-testing.md` with what works and what does not (evidence: docs/guides/device-testing.md)

### 9.2 Web

- [ ] ArkWeb component and `WebviewController` ownership
- [ ] `web.navigate`, `web.read`, `web.click`, `web.type`
- [ ] DOM text extraction via `runJavaScript`
- [ ] Per-task network toggle
- [ ] Download and file-picker approval
- [ ] Cookie and session isolation
- [ ] Signed-in site detection
- [ ] HTTPS allow-list for deep links
- [ ] Tests on 5 sites
- [x] `docs/reference/capabilities/browser.md` (evidence: docs/reference/capabilities/browser.md)

### 9.3 System intents

- [ ] Alarm via `Want` to Clock
- [ ] Calendar event via provider APIs
- [ ] Contacts read with user grant
- [ ] Share sheet
- [ ] Open link with scheme/host allow-list
- [ ] Install/uninstall with approval
- [ ] Settings deep links
- [ ] Tests for each intent
- [x] `docs/reference/capabilities/system.md` (evidence: docs/reference/capabilities/system.md)

### 9.4 Sandbox

- [ ] Bundle Pyodide and QuickJS in `rawfile`
- [ ] Pyodide and QuickJS artifacts are checksum-pinned on download and load
- [ ] Verify arm64 support, WASM memory limits and required features on the target devices
- [ ] Hidden ArkWeb page bridge
- [ ] Offline by default
- [ ] No device APIs exposed to scripts
- [x] Document that the HAP ships no Python runtime; Pyodide is an optional WASM page (evidence: docs/reference/capabilities/sandbox.md "The HAP ships no Python runtime")
- [ ] CPU, memory and wall-clock limits
- [ ] Network grant per run, logged
- [ ] Python package allow-list (pure wheels only)
- [ ] QuickJS limits documented
- [ ] 10 sandbox escape tests
- [ ] Startup time measured
- [ ] Companion Linux fallback documented, not built
- [x] `docs/reference/capabilities/sandbox.md` (evidence: docs/reference/capabilities/sandbox.md)

### 9.5 Platform edge cases

- [ ] Secure windows (banking, DRM): detect unreadable content and hand over
- [ ] Password and OTP fields: never read or type; hand over
- [ ] IME composition for Chinese and English; autocorrect off for codes
- [ ] Rotation, resolution and density changes mid-task
- [ ] Foldable, split-screen and multi-window layouts
- [ ] Lock screen: refuse to act and ask the user to unlock
- [ ] System permission dialogs that appear during a task
- [ ] Notification shade interaction, if the API allows it
- [ ] Clipboard read and write with consent
- [ ] App cloning, private space and multi-user profiles
- [ ] Managed-device (MDM) policy detection and refusal when automation is not allowed
- [ ] Overlay and tapjacking detection
- [ ] App update mid-run: re-read version and refresh knowledge
- [ ] Locale, time zone and date/number formats
- [ ] Dark-mode OCR check
- [ ] Low battery and power-saving behaviour
- [ ] Network loss mid-task
- [ ] VPN, captive portal and corporate Wi-Fi behaviour
- [ ] SIM roaming and metered-network warning before a data-heavy task
- [ ] Device reboot and service reconnect
- [ ] `hdc` disconnect and reconnect (tethered mode)
- [ ] Multi-device selection (tethered mode)
- [ ] `hdc` authorization onboarding: developer mode + RSA key
- [ ] USB and TCP connection modes
- [ ] `pc-agent` verified on Windows and macOS
- [ ] Unsupported-app list with a clear message
- [ ] Phone call and SMS actions with approval
- [ ] App-not-installed flow: offer AppGallery install with approval

### 9.6 Exit criteria (M4)

- [ ] M4 path: **standalone â€” ACL approved and verified, 20 tasks pass on a phone with no `hdc`**
- [ ] M4 path: **tethered fallback â€” release signed, 20 tasks pass over `hdc`** (one of the two must be checked)
- [ ] Every capability fails closed when unavailable
- [ ] No capability imports another capability

### 9.7 Permissions and packaging

- [ ] Full permission list with a one-line justification for each
- [ ] Each permission classified `user_grant` or `system_grant`
- [ ] `requestPermissionsFromUser` flow for every user-grant permission
- [ ] Denial path: explain, degrade gracefully, never loop on the prompt
- [x] ACL request form prepared for each restricted permission (evidence: docs/operations/acl-request.md; only ACCESSIBILITY_EXTENSION_ABILITY is requested)
- [ ] `module.json5` reviewed by a second person
- [ ] Privacy manifest / privacy statement matches actual data use
- [ ] HAR/HSP module boundaries chosen and documented
- [ ] Debug and release build variants separated
- [ ] Signing configs per environment, keys not in git
- [ ] AppGallery pre-check for accessibility and automation features
- [ ] Decision recorded: distributed/super-device features are not used
- [ ] Installation on a clean device from the release HAP verified
- [ ] Uninstall removes all app data

---

