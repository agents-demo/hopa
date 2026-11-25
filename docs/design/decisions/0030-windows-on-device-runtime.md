# ADR-0030 — On-device model runtime on Windows

- Status: accepted
- Date: 2026-11-25
- Owners: Windows lead, model owner

## Context

Windows must reach semantic parity with Android for the on-device small model
(MODEL-07…13). Android runs llama.cpp through JNI, uses GGUF files at Q4_K_M,
and keeps a catalogue whose entries carry size, licence, context and a
SHA-256. Its engine is grammar-capable and never falls back to the cloud.

The Windows client is a .NET 10 window plus a Kotlin sidecar in a separate
process. The sidecar already speaks OpenAI-compatible HTTP for cloud and LAN
providers. The on-device choice has to look the same in the receipt as it does
on the phone, must not be hidden behind a "lan" label, and must not silently
send a screen to a server.

The candidates were ONNX Runtime (with GenAI), llama.cpp, and Windows ML.

## Decision

- **Engine: llama.cpp.** The pinned CPU build (`b12721`) runs as a managed
  `llama-server` child process, bound to `127.0.0.1` on an ephemeral port.
- **Format: GGUF at Q4_K_M.** The curated default is Qwen3 1.7B (Apache-2.0),
  1,282,439,264 bytes, SHA-256
  `D2387CA2DBFEE2FFABCE7120D3770DADCA0B293052BC2F0E138FDC940D9BC7B5`,
  context 32,000. Thinking is disabled for turns (`--reasoning-budget 0`),
  because Qwen3 otherwise spends the answer budget before the decision.
- **Distribution.** The runtime archive and the model are downloaded on first
  use, verified against a SHA-256, and stored under
  `%LOCALAPPDATA%\HOPA\local` and `%LOCALAPPDATA%\HOPA\models`. Neither is
  inside the MSI. A person may import their own `.gguf` (magic checked) and
  delete any model from Settings.
- **Process boundary.** The window owns the server. The sidecar reaches it
  through `HttpLocalEngine`, a `LocalEngine` over the OpenAI-compatible
  endpoint. The provider stays **`on-device`**; only loopback addresses are
  accepted (`LocalEndpoint.isLoopback`), and anything else leaves
  `LocalModel(null)`, which fails visibly.
- **Timing.** A local turn gets a ten-minute deadline in the sidecar and an
  eleven-minute wait in the window; one decision is capped at 256 tokens.
- **Licence.** The first download asks for acceptance and shows the licence
  URL; the catalogue entry is the source of truth.
- **No silent fallback.** A local failure is an error in the answer. Consent-
  based local→API fallback remains MODEL-11 and is not implied here.

## Consequences

- Windows and Android share the same model bytes, digests and catalogue
  entries.
- First use needs a network download (about 1.3 GB of weights plus a 25 MB
  runtime); afterwards the turn is fully offline.
- CPU turns are slow: one measured two-step turn took 4 min 17 s on this
  machine. The chat must show live progress and offer a switch to the API
  (MODEL-16/17), not a silent spinner.
- No NPU or GPU acceleration in v0; that is a separate budget.
- Vision is off for the bundled model: `llama-server` rejects image input
  without an `mmproj`.
- The sidecar does not link llama.cpp. The window owns process lifetime,
  restarts the server when the model file changes, and keeps it on loopback.
- GBNF grammar is not forwarded over HTTP. The decision parser still validates
  the reply shape, so a malformed answer is an error, not an action.

## Alternatives considered

- **ONNX Runtime / Windows ML:** a different file format (ONNX), an
  NPU/driver dependency, no shared digests with Android, and extra runtime
  redistribution. Rejected for v0.
- **Link llama.cpp into the sidecar:** adds a native build and a platform
  matrix to the sidecar. The process split already exists and `HttpClient` is
  enough.
- **Map on-device to the LAN provider:** rejected. The receipt would claim an
  endpoint the person did not choose, and the "nothing leaves this machine"
  promise would rest on configuration rather than on code.
- **Bundle the model in the MSI:** rejected. Installer size budget, updates,
  and models are data, not code.
- **Silent cloud fallback:** rejected. It is a privacy decision and needs
  explicit consent.
