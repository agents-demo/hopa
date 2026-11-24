# P5 takeover and signature evidence

Date: 2026-11-24. Host: Windows 11, .NET 10, JDK 21 package.

## Command

```powershell
Hopa.Windows.DevTools.exe --p5-check <dir>
```

No `--auto-sign`: the person typed `Michael` into **Signature** and pressed
**Submit** while the turn was paused.

## Transcript

```text
target: this PC (the bridge target was restored afterwards)
foreground: Hopa.Windows.DevTools
form visible: True
prefill: Michael
operator: human
paused: True
signed: Signed by Michael
answer: Confirmed - the form is signed. Full name is Michael, the signature
field reads Michael, and the page shows "Signed by Michael".
checkpoint complete: True
checkpoint missing:
```

Artifacts:

- [p5-paused.png](P5/p5-paused.png) - the form while the turn is paused;
- [p5-signed.png](P5/p5-signed.png) - the signed form with the visible label;
- [p5-check.txt](P5/p5-check.txt) - the transcript above.

## What this proves

- `turn.start` with `paused` pauses **before the first step**;
- `turn.resume` returns `StepGate.Refresh`, so the loop re-observes;
- the final screen carries `Signed by Michael` and `GoalVerifier` marks the
  checkpoint complete;
- a human, not the harness, performed the signature. The model's prose is not
  the evidence; the checkpoint and screenshot are.

The foreground fix attaches to the current input thread before
`SetForegroundWindow`; without it Windows refused to bring the check window
forward and the run failed honestly instead of observing the wrong screen.
