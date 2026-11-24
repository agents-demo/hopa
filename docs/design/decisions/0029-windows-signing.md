# ADR-0029 — Windows installer signing and release identity

- Status: accepted
- Date: 2026-11-24
- Owners: Windows lead, release owner

## Context

The Windows v0 package is a self-contained client, sidecar jars and a jlink
runtime inside a WiX MSI. The MSI is currently unsigned. SmartScreen reputation
and `uiAccess` both depend on an Authenticode signature, and a signed installer
is the release gate in P6/W11.

Signing is also calendar-bound: identity validation, a certificate profile and
timestamping need lead time. It cannot be the last engineering step.

## Decision

- Sign **both** the product exe and the MSI with Authenticode, SHA-256,
  timestamped. Verify with `signtool verify /pa` before publishing.
- Support three credential paths behind one interface: a PFX provided through a
  secret environment variable, a certificate in the Windows store, and Trusted
  Signing (dlib + metadata: endpoint, account, profile).
- Never pass a PFX password on the command line. Use a secret env var or the
  certificate store.
- Name unsigned build artifacts with `-unsigned`; they must not look
  releasable.
- Record the SHA-256 **after** signing and attach it to the release artifact.
- The installer must assert the WebView2 Evergreen runtime (or ship a fixed
  runtime); the browser surface is otherwise unavailable on a clean VM.
- v0 is **x64 only**; ARM64 is a separate budget.

## Consequences

- The release gate is a signed exe+MSI on a clean VM with two turns.
- CI can build unsigned artifacts for every PR, but only a signed artifact is
  called a release.
- A missing certificate blocks release, not development.
- `uiAccess` remains false until the signed helper and Program Files install
  exist; the signature is a prerequisite, not a substitute.

## Alternatives considered

- **Sign only the MSI:** rejected; the exe in the zip stays unsigned and
  `uiAccess` cannot work.
- **Store the PFX password in the repository or command line:** rejected;
  leaks through process listings and logs.
- **Skip the clean-VM gate:** rejected; a signed MSI that cannot install the
  runtime is not a release.
