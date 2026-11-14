# Security policy

## Supported versions

| Version | Supported |
|---|---|
| `0.1.x` | yes |

## Reporting a vulnerability

Use GitHub's **private security advisory** on
<https://github.com/agents-demo/hopa/security/advisories/new>. Do not open a
public issue for a vulnerability.

Include:

- affected component (`agent`, `hopa-bridge`, `brain`, `app`);
- version or commit;
- reproduction steps;
- impact (data, payment, account, availability).

We aim to acknowledge within 72 hours and to ship a fix or mitigation within 30
days for confirmed high-severity issues.

## Scope

In scope:

- the execution gate and policy bypasses;
- payment or emergency-number bypasses;
- prompt injection that changes actions;
- URL allow-list bypasses;
- secret leakage in logs, records or the repository;
- the hash-chain record;
- the brain HTTP service.

Out of scope:

- issues that require a rooted or jailbroken device;
- Huawei platform vulnerabilities;
- denial of service against a local dev machine;
- social engineering.

## Secrets

- Never commit an API key, signing key or password.
- PC: the key lives in an environment variable.
- Device: the key belongs in HUKS, never in preferences or logs.
- `gitleaks` (or an equivalent scanner) is expected in CI before a public
  release.

## API key rotation

1. Create a new key at the provider.
2. Update the environment or HUKS entry.
3. Restart the rig or app.
4. Revoke the old key.
5. Check records and logs for the old key prefix; purge if found.

## Provider compromise playbook

1. Revoke the key.
2. Switch the fallback provider.
3. Stop runs that are in flight.
4. Purge local logs and diagnostic bundles that contain prompts.
5. Notify users if their data may have been exposed.
6. Record the incident and the timeline.

## Disclosure

We support coordinated disclosure. We will credit reporters unless they ask to
remain anonymous.
