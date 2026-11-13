# A9 - chat shell

Date: 2026-11-13. One item is complete: the empty state.

## Verified on the emulator (`hopa35`, API 35)

- `ChatEmptyState` renders the mascot, the greeting by hour (`Good evening`),
  the HOPA wordmark, "Your assistant. Ask for anything.", "Payments always ask
  first.", the `Try an example` pill with three suggestions and the ritual pill
  (`Evening close?` after 18:00).
- The chips sit 10 dp above the composer (`bottom = 6` + `top = 4`), matching
  `ChatPage`'s `Column({ space: 10 })`.
- `Chats` beside the clock opens the large sheet; the bubble appears on a mascot
  tap and disappears after 2 200 ms.

Screens: `docs/media/android-chat-2026-11-13.png`,
`docs/media/android-capabilities-2026-11-13.png`.

## Not done in A9

- No typed routes, predictive back, `hopa://ask?text=` deep link or app
  shortcuts.
- The bottom bar is not profile-aware (one bar for every profile).
- The approval is a Compose dialog fed by an in-process flow; it is not
  service-owned, does not survive process death and has no timeout.
- Chat has no step chips, verification line, "What HOPA saw", changed chip,
  undo, retry, copy or FileProvider share.
- Composer: IME Send and `imePadding` exist; hardware Enter/Shift+Enter, the
  four-state round control and dictation do not.
- No TalkBack/200% font pass and no explicit 48 dp audit.
- The draft lives in the ViewModel, not `rememberSaveable`.
