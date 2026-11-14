# A10 - Easy profile (first slice)

Date: 2026-11-14. Verified on `emulator-5554`, API 35.

## Done

- `HomeShell` reads the persisted profile and, for `easy`, switches to its own
  shell: the bar becomes **Talk / History / Settings** (`HopaBottomBarEasy`,
  same 64dp geometry, 48x28 pill, 11sp labels, 22dp custom icons).
- Talk is the chat with the Easy bar; History is `EasyHistoryScreen`: cards with
  title, last-message preview and a Today/Yesterday/date label; tapping a card
  selects that conversation (`selectedConversation`) and returns to Talk.
- Settings in the Easy bar opens the Settings route.
- The shared `HopaTabIcon` was extracted so both bars draw the same icons and the
  settings icon exists.

## Verified live

1. Settings → Profiles → Easy.
2. The shell bar changed to **Talk / History / Settings**.
3. History listed the existing chats; tapping one returned to Talk with that
   conversation open.

## Not done (A10 remains open)

- The Easy landing details: a dedicated greeting screen, the talk sheet states
  (input / working / done), **Read it again**, stop, help panel, keypad with
  `ACTION_DIAL`, footer, and the separate 30-entry Easy task log.
- Easy history detail and "edit this request" refill.
- Kid, Power and Social homes.
- Haptics/tactile, the three appearance modes, dynamic colour, per-profile
  visual styles.
