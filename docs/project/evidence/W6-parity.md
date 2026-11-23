# W6 parity: the look, Harmony laptop vs Windows

Reference values are read from the code on both sides, not from screenshots:
`apps/harmony/laptop/src/main/ets` and `apps/windows/Hopa.Windows/Shell/MainWindow.xaml`.
The Windows screenshot is `docs/media/windows-w4.png`.

## Tokens

Reference values are in `W6-harmony-spec.md`. Windows values are the ones in
`MainWindow.xaml` and `App.xaml` after the port.

| Token | Harmony | Windows | Same? |
|---|---|---|---|
| bg | `#F7F4EE` | `#F7F4EE` | yes |
| surface | `#FFFFFF` | `#FFFFFF` | yes |
| surface_alt | `#F3EFE7` | `#F3EFE7` | yes |
| surface_muted | `#F1ECE3` | `#F1ECE3` | yes |
| text_primary | `#1C1B18` | `#1C1B18` | yes |
| text_secondary | `#6B665C` | `#6B665C` | yes |
| text_hint | `#9A9488` | `#9A9488` | yes |
| primary (actions) | `#0A59F7` | `#0A59F7` | yes |
| primary_soft | `#E8F0FF` | `#E8F0FF` (rail steps) | yes |
| accent (brand) | `#E8703A` | `#E8703A` | yes |
| divider | `#E9E4DA` | `#E9E4DA` | yes |
| user bubble radius | 14 | 14 | yes |
| pill radius | 24 | 24 | yes |
| rail card radius | 14 | 14 | yes |
| type scale used | 9 · 9.5 · 10.5 · 11.5 · 12.5 · 13.5 · 15 | same | yes |

One correction to the earlier reading: the blue `#0A59F7` is Harmony's **primary
action** colour, not a Windows default that slipped in. The accent orange is the
brand mark only. The first port had this backwards and is now fixed: Send, Allow
and Save are blue; the mascot and pin markers stay orange.

## Components

| Component | Harmony | Windows | Notes |
|---|---|---|---|
| rail with title, search, archived toggle | yes | yes | same structure |
| conversation row: title, pin marker, time, archived marker | yes | yes | Windows adds a pin label |
| message bubbles, user right / assistant left | yes | yes | Windows max width 640 |
| composer with attach, mic, send/stop | yes | yes | Windows adds a copy button |
| attachment bar above the composer | yes | yes | same 4 MiB cap |
| approval sheet | yes | yes | Windows is a separate window |
| settings window | yes | yes | provider, key, bridge, tone |
| empty state | yes | yes | "Ask me something."; search now has a placeholder |
| error state | inline text | status line under the composer | Windows is quieter |
| long text | wraps | wraps | screenshot needed at 200% |

## States

| State | Harmony | Windows |
|---|---|---|
| hover | custom tint | `#F3EFE7` tint, one template for every button and row |
| focus ring | custom | `#E8703A` 1.5 px ring on the focused control |
| pressed | darker tint | `#E9E4DA` |
| selected conversation | tinted row | `#E9E4DA` row |
| disabled control | dimmed | 0.45 opacity, arrow cursor |
| busy (turn running) | send becomes stop | send becomes stop, tray says "working" |

The states live in `App.xaml`: one `Button` template and one `ListBoxItem`
template, so a new button cannot drift.

Keyboard: `KeyboardNavigation.TabNavigation=Cycle`, 17 focusable controls, 13 of
them named for UIA (`w4-check.txt`).

Screenshots so far (all rendered by the app itself, not captured by hand):

| Screenshot | Shows |
|---|---|
| `docs/media/windows-w4.png` | rail, conversation row, composer, empty state |
| `docs/media/windows-w6-settings.png` | settings, provider fields, orange Save |
| `docs/media/windows-w6-approval.png` | approval sheet with amount, merchant, consequence |
| `docs/media/windows-w6-steps.png` | run details, one line per step |

Also rendered: `docs/media/windows-w6-chat.png` — bubbles with real content, a
long answer, the attachment bar and an error line. With it the inventory is
complete: rail, row, bubbles, composer, attachment, approval, settings, empty
state, error state and long text all appear in one of the four shots.

Keyboard order, recorded by `--keyboard-check`:

```
tab order (visual tree): New chat -> Search conversations -> Show archived
conversations -> Settings -> Conversations -> window buttons -> composer ->
Dictate a message -> Send message
focusable stops: 14
focus ring: #E8703A, 1.5 px, from the shared Button and ListBoxItem templates
```

Not done: high contrast still does not change the palette, and 200% has not been
run with system scaling.

## Keyboard and scaling

- Shortcuts: Ctrl+N, Ctrl+F/K, Enter, Shift+Enter, Esc — present on both, verified
  on Windows in `w4-check.txt`.
- Full tab-order pass: **not done**.
- 200% scaling: **not verified**; 150% is proven by `density=1.5` in W3.
- High contrast: detected (`SystemParameters.HighContrast`), but the palette is
  fixed, so high contrast does **not** yet change the look.

## Window chrome

A real screen grab (`--shot-frame`) shows the rounded frame, the hidden
scrollbars and the Segoe UI Variable type. The dotted focus rectangle is gone
system-wide (`SystemParameters.FocusVisualStyleKey` is overridden with an empty
template) and buttons/rows draw the `#E8703A` ring instead.

## What closing W6 means

1. One type scale and one radius scale, taken from the Harmony code.
2. Hover and focus states written once and shared by every control.
3. A high-contrast palette that switches on `SystemParameters.HighContrast`.
4. Screenshots side by side at 100%, 150% and 200%, then the table above with no
   "no" or "not verified" left.
