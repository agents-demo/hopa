# M0 decisions and signing procurement

Status: **decided for the M0 baseline.** These are the inputs later phases must
not rediscover.

## Platform floor

- **OS:** Windows 11, x64. Windows 10 reached end of support in 2025; ESU is not
  a supported product path.
- **Runtime:** self-contained .NET 10 for the client; JDK 21 jlink runtime for
  the sidecar. Users never install .NET or Java.
- **WebView2:** Evergreen runtime, with a minimum version check at browser
  startup. If the runtime is missing or older, the browser row falls back to
  link-out and `web.read/click/type` return a real error; the app does not
  pretend the surface exists.
- **ARM64:** not in v0. A second jlink runtime and installer are a separate
  budget.

## Protocol

JSON Schema for payload types; NDJSON v1 stays on the wire. Protobuf is
rejected in ADR-0028. Golden frames are the compatibility fixture, and the
run-record hash chain is not regenerated.

## Signing procurement checklist

This is calendar work, not a coding task. The release owner tracks it.

- [ ] Choose the identity path: PFX in a secret store, certificate in the
      Windows store, or Trusted Signing.
- [ ] Complete identity/organization validation for the chosen path.
- [ ] Create the certificate profile / code-signing account and record its
      endpoint, account and profile names.
- [ ] Choose the RFC 3161 timestamp URL and confirm it is reachable from CI.
- [ ] Store the credential in the release secret store; no PFX password in a
      command line, repository file or log.
- [ ] Sign the **exe and the MSI**; verify with `signtool verify /pa`.
- [ ] Decide the unsigned-artifact naming (`*-unsigned`) and who may download
      it.
- [ ] Record the SHA-256 after signing and attach it to the release.
- [ ] Confirm the installer asserts the WebView2 Evergreen runtime.

## Baseline evidence

`docs/project/evidence/M0-baseline.md` holds the measured net8 baseline. The
harness is `tools/scripts/windows-baseline.ps1`; run it again after M1a with
`-Framework net10.0-windows` and record the delta. Cold start is outlier-prone;
the median and p95 are both reported.
