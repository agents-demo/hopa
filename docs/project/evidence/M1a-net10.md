# M0 baseline

Measured on the machine below. Re-run with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/windows-baseline.ps1
```

| Field | Value |
|---|---|
| OS | Microsoft Windows 11 Pro 10.0.26200 |
| CPU | Intel(R) Core(TM) Ultra 7 255U |
| .NET SDK | 10.0.201 |
| Java | openjdk version "17.0.19" 2026-04-21 LTS |
| Client TFM | net10.0-windows |
| Samples | 20 cold starts; 5 headless turns |

| Metric | Median | p95 |
|---|---:|---:|
| Cold start (ms) | 2357 | 28888 |
| Idle working set (MB) | 197 | 211 |
| Unit tests (ms) | 16810 | - |
| Integration tests (ms) | 3249 | - |
| Headless turn (ms) | 529 | 675 |

| Package | Bytes |
|---|---:|
| zip | 116787544 |
| MSI | 104438278 |

The cold-start loop closes the main window after the first handle; it does not
measure a full turn. Headless turns use the scripted model, so they are a
toolchain regression signal, not a model-latency budget.

## M1a behavioural smoke

| Surface | Result |
|---|---|
| WebView2 | --web-check: signed visible: True; type/click/read on a loopback form |
| Tray/toast/W4 | --w4-check: tray icon, stop-disabled, tooltip, shortcuts, toast shown through the tray balloon |
| UIA + takeover | --p5-check --auto-sign: paused: True, checkpoint complete: True |
| Vision | --vision-check: WINTER -> WINTER, match: True |
| Self-contained publish | dotnet publish -r win-x64 --self-contained: window handle appeared; no machine .NET required |
| Voice | not run: it needs a live bridge at the configured URL; the TFM change does not touch the voice client |

Median cold start moved from 2896 ms (net8 baseline) to 2357 ms (net10), but both p95s are dominated by startup outliers; this is not a latency claim. All C#/integration suites pass on net10.
