# Threat model (v1)

Scope: the HOPA app, the PC evaluation rig and the JVM brain service.

## Assets

| Asset | Why it matters |
|---|---|
| Screen content | May contain messages, accounts, balances, health data |
| Credentials and OTPs | Account takeover |
| Payment authority | Direct financial loss |
| Run records | Audit trail and personal history |
| Model API key | Cost and data exposure |
| User attention | A convincing but wrong action is still harm |

## Actors

- malicious or compromised app on the device;
- malicious web page or document (indirect prompt injection);
- attacker with brief physical access;
- dishonest or compromised model provider;
- supply-chain attacker in a dependency;
- a user trying to abuse the agent (spam, fraud, scraping).

## Threats and mitigations

| ID | Threat | Mitigation | Residual |
|---|---|---|---|
| T1 | Screen text tells the model to ignore its rules | Screen text is untrusted data in the user message; system rules are separate; policy still asks | Model may still be confused |
| T2 | Payment misclassified | Screen-semantic classifier, fail-closed, 100% payment bench target | New payment wording may be missed |
| T3 | Agent types a password or OTP | `ui.type` on a password/OTP screen is blocked; handover | User may still paste a secret |
| T4 | Data exfiltration to an unapproved URL | `UrlPolicy` in the executor, https-only, host allow-list, no userinfo | Allowed host can still leak |
| T5 | Overlay or tapjacking | Sensitive-screen detection; no blind taps; record before/after | Platform-level overlays |
| T6 | Screenshot leak | Opt-in, redaction, retention policy, no screenshots in records | User may export one |
| T7 | Record tampering | Append-only hash chain, `verify-chain` | Attacker with write access can replace the whole file |
| T8 | API key theft | Env on PC, HUKS on device, never logged | Compromised host |
| T9 | Supply-chain compromise | Pinned versions, lockfiles, review, checksum-pinned WASM | Zero-days |
| T10 | Abuse (spam, fraud, scraping) | Rate limits, refusal taxonomy, CAPTCHA handover | Determined user |

## Trust boundaries

```
user ── UI ── loop ── model provider
                 │
                 ├── executor (policy, URL, limits)
                 │
                 └── device capabilities (a11y, web, system)
```

The model is **outside** the trust boundary. The executor is the enforcement
point.

## Review

- Revisit before each milestone.
- A new action kind requires a threat-model update in the same PR.
- External pen-test before a public release.
