# W1 — the shell

Date: 2026-11-14. Host: Windows; .NET 8 (WPF); JDK 17.

The window stopped being a debug console: it is now the three-part HOPA layout,
and conversations survive a restart.

## What exists

- **Sidebar** (260 px): the orange dot and `HOPA`, `+ New chat`, and the
  conversation list with a title and a time (`15:15` / `14 Nov`).
- **Chat column**: a 52 px header with the conversation title, blue user bubbles
  on the right, white assistant bubbles on the left, and the mascot with
  "Ask me something." when a thread is empty.
- **Composer**: Enter sends, Shift+Enter keeps the line break.
- **Palette** copied from `HopaColor`: `#F7F4EE` background, `#F3EFE7` sidebar,
  `#0A59F7` primary, `#E8703A` accent, `#1C1B18` text.
- **No system title bar**: `WindowChrome` hides the decoration, the top 52 px
  drags, and the minimize/maximize/close buttons live in the header (the same
  shape as the Harmony laptop's `decorHidden` mode).
- **Persistence** in the sidecar: `%USERPROFILE%\.hopa\windows\conversations.json`
  (JSON store over `packages/data` models, now `@Serializable`).
- **Drafts** per conversation, kept in memory (implemented, not yet verified by
  hand; the box stays open).

## Verification

```
Hopa.Windows.exe --turn "say hello" --out turn1.txt
Hopa.Windows.exe --turn "how are you today" --out turn2.txt
Hopa.Windows.exe --list --out list.txt
```

```
turn1: sidecar: [sidecar] turn r-e946... in c-28313c64-ab85-4ba3-a2af-c6e1d6a17fe4: say hello
       HOPA: Sidecar answered: "say hello".
turn2: sidecar: [sidecar] turn r-7ec6... in c-28313c64-ab85-4ba3-a2af-c6e1d6a17fe4: how are you today
       HOPA: Sidecar answered: "how are you today".
list:  c-28313c64-ab85-4ba3-a2af-c6e1d6a17fe4 | say hello | 4
```

The same conversation id in both runs and four messages in the list is the
restart proof: the second process loaded the first process's thread.

`python tools/scripts/windows-smoke.py`:

```
turn: ok
list: ok
screenshot: docs/media/windows-w1.png
```

The screenshot is `docs/media/windows-w1.png` (sidebar, header, bubbles,
composer).

## Fixed on the way

- `ConnectAsync` returned early while `RefreshAsync` was still listing, so a
  headless turn started before the list arrived and created a new conversation
  every run. One shared connect task fixes it.
- `SpikeModel` read the *first* user message, so with history every answer
  repeated the old goal. It reads the last user message that is not a SCREEN
  render.

## Not done

- Settings (model provider and key in Credential Manager, bridge address and
  token, tone): the box is open.
- Draft reuse needs a hand check: switch conversation, type, switch back.
- The model is still the scripted `SpikeModel`; a real provider, approvals and
  stored run records are W2.
- No share, voice, notifications or tray yet (W4).
