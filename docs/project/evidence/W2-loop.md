# W2 — loop, phone target and approvals

Date: 2026-11-14. Host: Windows; .NET 8 (WPF); JDK 17; `emulator-5554`; the PC
bridge on `127.0.0.1:8899`.

The window now drives the phone, and sensitive actions ask the person first.

## What changed

- The sidecar picks the device per turn: the **bridge `AdbDevice`** when settings
  carry a URL and token, otherwise the W1 host device.
- The model is real when a key is configured (`ModelFactory`); the scripted
  `SpikeModel` remains the no-key fallback.
- **Approvals travel to the window**: `approval.request` -> a modal sheet ->
  `approval.result`; a 120 s wait, then deny.
- `turn.end` carries the run records; the header has a **Run** button that opens
  the steps with classification, approved, executed, verified, error and hash.

## Bridge turn

```
Hopa.Windows.exe --bridge-check http://127.0.0.1:8899 testtoken out.txt
```

```
sidecar: configured: bridge=on url=http://127.0.0.1:8899 model=none tone=warm
sidecar: turn ...: open settings on the phone
HOPA: Sidecar answered: "open settings on the phone".
step #0 ui.launch [read] approved= executed=True verified=True error= hash=sha256:712
```

`adb shell dumpsys window` after the turn:

```
mCurrentFocus=Window{... com.android.settings/com.android.settings.Settings}
```

The second run of the same goal reports `verified=False`: Settings was already in
the foreground, so the before/after observation hash did not change. That is the
verification rule working, not a failure.

## Approvals

Payment goal, allow and deny:

```
approval: auto-allow Confirm payment
HOPA: Sidecar answered: "I could not do that: unsupported kind: payment.pay".
step #0 payment.pay [payment] approved=True executed=False verified=False error=E_UNSUPPORTED

approval: auto-deny Confirm payment
HOPA: Sidecar answered: "I did not run that.".
```

The host still cannot execute `payment.pay` (W3/W5 own real payments); what this
proves is the gate: the request reached the window, the answer came back, and a
deny stopped the action before the device.

## Bridge down

```
HOPA: Sidecar answered: "I could not do that: bridge unreachable: Failed to connect to /127.0.0.1:8898".
step #0 ui.launch [read] approved= executed=False verified=False error=E_DEVICE
```

## Not done

- **A pending approval does not survive a restart yet**: it is held in memory
  and times out after 120 s. The plan box stays open.
- **Records are per-turn, not persisted**, and the dialog shows the hash but does
  not re-walk the chain. The box stays open.
- **One 401 refresh** on the bridge was not exercised; the bridge-down case was.
- The answer text comes from the scripted model; a real provider needs a key in
  Settings (W2 box for the model, not yet ticked).
