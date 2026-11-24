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
| Client TFM | net8.0-windows |
| Samples | 20 cold starts; 5 headless turns |

| Metric | Median | p95 |
|---|---:|---:|
| Cold start (ms) | 1917 | 9559 |
| Unit tests (ms) | 3336 | - |
| Integration tests (ms) | 5552 | - |
| Headless turn (ms) | 781 | 872 |

| Package | Bytes |
|---|---:|
| zip | 116787544 |
| MSI | 104438278 |

The cold-start loop closes the main window after the first handle; it does not
measure a full turn. Headless turns use the scripted model, so they are a
toolchain regression signal, not a model-latency budget.
