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

## Pending approvals survive a restart, then are denied

While an approval was waiting, the sidecar wrote `approvals.json`. The process
was stopped and a new sidecar started:

```
sidecar: denied 1 pending approval(s) on restart
```

The file is `{}` afterwards. The rule matches Android: survive a rotation, deny
on process death, time out after 120 s. (The kill happened after the sheet
request was accepted by the sidecar; the dialog itself is the same one the
allow/deny runs above exercise.)

## Records and the chain

```
step #0 ui.tap [read] approved= executed=True verified=True error= hash=sha256:5b6
chain: ok
```

The sidecar appends each turn's records to `records.json` (912 B after the
click) and runs `RunChain.verify` before replying; `turn.end` carries
`chainOk`. The Run button shows the same lines with the chain state.

## Bridge down and the 401 refresh

Unreachable bridge:

```
HOPA: Sidecar answered: "I could not do that: bridge unreachable: Failed to connect to /127.0.0.1:8898".
step #0 ui.launch [read] approved= executed=False verified=False error=E_DEVICE
```

Stale token. A second bridge on `127.0.0.1:8897` was paired (`pair: ok`,
`refresh stored: True`), then its refresh endpoint was called once so the stored
access token became stale while the refresh token stayed valid. The turn then
used the stale token:

```
sidecar: configured: bridge=on url=http://127.0.0.1:8897 model=none tone=warm
sidecar: bridge token refreshed
HOPA: Sidecar answered: "open settings on the phone".
step #0 ui.launch [read] approved= executed=True verified=False error= hash=sha256:e78
chain: ok
stale check: rotation=ok token_changed=True
```

One 401, one refresh, the rotated token retried the action. `verified=False`
because Settings was already in the foreground.

## Not done

- The answer text comes from the scripted model; a real provider needs a key in
  Settings (the model box stays open until a key is present).
