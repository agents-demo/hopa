# Capability coverage

Status on the Pura 90 emulator (HarmonyOS 6.1.0.126, API 24) on 2026-11-08.
"Works" means verified end to end on this image. "With the PC bridge" means the
bridge must be connected. "Not on this image" is a platform limit, not missing
code.

| Capability | Status | Notes |
|---|---|---|
| Chat and reasoning | Works | Blue/grey bubbles, natural replies, no raw action logs; tokens and duration are recorded. |
| Navigation | Works | Bottom bar: Chat, Activity, Capabilities. **History** sheet with search, date groups and the active chat pinned; Activity = runs, screens and plans; Capabilities = apps, browser, memory, models, access and the app pages; Settings behind the gear. |
| Appearance | Works | System/Light/Dark switch in Settings; semantic colour tokens with a dark palette. |
| Built-in browser | Works | Read a page, click, type; compact toolbar; one tab; the visible sandbox demo is gone. |
| Website task from Chat | Works | One prompt opens the browser, reads the page and answers; verified with Bilibili. |
| Chat page link | Works | After a web task the chat keeps the page title, URL and an Open button; verified with example.com. |
| App control | With the PC bridge | Launch, read the screen, tap, type, scroll and go back. |
| Untethered app control | Not on this image | The accessibility settings page is missing. A real phone with the service enabled is the untethered path. |
| Approval sheet | Works | A bottom sheet owned by the shell, so it appears over Chat or Browser; human titles and labels instead of action kinds and refs; unit tested. |
| Payment gate | Works | Every payment asks, in every mode. A denied action is still recorded. |
| Memory | Works | Explicit facts, automatic "remember ..." extraction, visible and deletable. |
| Skills | Works | Saved skills, a draft from a successful run, uses/successes counters. |
| Plans (in-app) | Works | Once, every 5 minutes, every 30 minutes, daily; they fire while HOPA is open. |
| System reminders | Not on this image | The reminder API returns `1700002`; nothing fires after the app closes. |
| Batch | Works | Sequential goals, stop between items, per-item duration. |
| Runs and export | Works | History, approval/payment flags, per-run detail, JSON export. |
| Models | Works | OpenAI-compatible, Anthropic, Gemini, DeepSeek. The key is memory-only. |
| PC tools | Works | `hopa-bridge` CLI, MCP stdio server and the HTTP bridge. |
| Speech | Not available | No `CoreSpeechKit` in this SDK/image. |
| JavaScript sandbox | Works | Isolated `about:blank` WebView, offline. |
| Python/WASM/Linux sandbox | Not built | The optional Python/WASM assets are not bundled; Linux is out of scope. |
| Languages | Partial | Ten fixed strings for the shell and greeting; newer pages are English-only. |

## Verified end to end on this image

- Chat answered a question about the page loaded in the built-in browser and
  recorded **400 tokens**; the run was saved as a skill.
- A second run answered with no screen at all; a batch finished in 2 s with
  **409 tokens**.
- The bridge connected over `10.0.2.2:8765`, observed the device, the model
  chose a `ui.tap`, the bridge executed it, and the loop re-observed.
- `Open Settings and tap Network and internet.` ran in one request: router chose
  Settings, bridge `/launch`, `/observe`, `ui.tap e8`, `/observe` showed the
  WLAN page.
- `Answer in Chinese: summarize the 2 hottest Bilibili videos today...` ran in
  one request: `web.navigate` → `web.read`; the chat listed the two videos and
  view counts in Chinese, and the Bilibili page showed the video cards.
- The app catalogue and site catalogue are current; the structure and link
  checks are clean.

## What is limited, and why

- **The emulator is not a phone.** Its accessibility settings page is missing,
  so app control is tethered to the PC. `uitest` can stall, and some system APIs
  fail.
- **Retail devices need the AppGallery ACL** to enable the accessibility
  extension. A debug-signed build with the service enabled works on a real
  phone; this is an account/legal step, not code.
- **Twenty catalogue apps are not installed on this image.** Fifteen also have
  no verified HarmonyOS bundle. HOPA refuses to launch a guessed package.
- **No background screen.** HOPA drives the visible screen only.
- **Login, CAPTCHA and verification codes stay with the user.**

For the dated history and the open gaps, read
[status-2026-11-07.md](../../project/archive/status-2026-11-07.md).
