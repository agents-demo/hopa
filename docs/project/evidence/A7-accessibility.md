# A7 - accessibility adapter

Date: 2026-11-13. One item (typing) is complete; the rest is in progress.

## Typing

`AccessibilityDevice.type`:

1. takes the ref from the last observation and refuses stale refs;
2. sends `ACTION_FOCUS` first;
3. sets `ACTION_SET_TEXT` with the text as a `CharSequence`;
4. falls back to the clipboard plus `ACTION_PASTE` when the field refuses;
5. throws "the field refused the text" instead of pretending.

Non-ASCII text works through the same path.

## Also present, not yet a closed item

- Service declaration and `accessibility_service_config.xml`
  (`canTakeScreenshot`, gestures, window content).
- `NodeTreeReader` over the active window, ignoring HOPA's own package.
- Gestures: tap and swipe through `dispatchGesture`; back and home through
  global actions.
- Screenshot via `takeScreenshot`.

## Not done in A7

- No disclosure screen and no kill switch.
- No double-tap or long-press gesture; scroll is a swipe.
- No `FLAG_SECURE` handling, no 1/s screenshot limit, no tree-only fallback.
- No per-action re-check of `enabledServices`, so a revoked service is not failed
  closed.
- No `ObservationProducer`, so the observation is not proven equal to the bridge
  path for a fixture screen.
- No tests and no run on a real phone; the emulator test of the live instance
  failed when the service was enabled through `adb`.
