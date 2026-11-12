# Owners, skills and dependencies

Status: acting, one maintainer. Replace "acting" with a real name and add a
second reviewer before M5.

## Phase owners

| Phase | Owner | Reviewer |
|---|---|---|
| 0 Foundations | michaelatamuk (acting) | second reviewer required |
| 1 Harness | michaelatamuk (acting) | second reviewer required |
| 2 Brain | michaelatamuk (acting) | second reviewer required |
| 3 ArkTS core | unassigned — hiring gap | — |
| 4 Capabilities | unassigned — hiring gap | — |
| 5 Safety | michaelatamuk (acting) | security reviewer required |
| 6 Product/UI | unassigned — hiring gap | — |
| 7 Evaluation | michaelatamuk (acting) | second reviewer required |
| 8 Release | michaelatamuk (acting) | product owner required |
| 9 Optional | michaelatamuk (acting) | — |

## Skills matrix

| Skill | Level | Notes |
|---|---|---|
| Python | strong | evaluation rig, bench, contracts |
| Kotlin/JVM | partial | router and HTTP service; full port not started |
| ArkTS / ArkUI | gap | no build has run |
| HarmonyOS accessibility | gap | ACL not filed, no device |
| Security review | partial | threat model written; external review pending |
| Documentation | strong | ADRs, contracts, status |
| Test engineering | strong | 222 Python tests, 34 Kotlin assertions |

## Hiring or contracting gap

1. ArkTS / HarmonyOS engineer for Phase 3 and Phase 6.
2. Accessibility specialist for Phase 4 and the ACL submission.
3. External security reviewer before M5 and a public release.

## Dependencies

| Dependency | Owner | Lead time | Blocks |
|---|---|---|---|
| Accessibility ACL | Huawei | 4–8 weeks | M4 standalone |
| Physical HarmonyOS 6+ phone | procurement | 1–2 weeks | device baseline |
| DevEco Studio 26 + SDK | local install | 1 day | ArkTS build |
| AppGallery developer account | Huawei | 1–2 weeks | distribution |
| Model provider key and budget | product owner | 1 day | real-model bench |

## Documentation ownership

| Page | Owner |
|---|---|
| `docs/plan/README.md` | michaelatamuk |
| `docs/architecture/overview.md` | michaelatamuk |
| `docs/contracts/*` | michaelatamuk |
| `docs/adr/*` | michaelatamuk |
| `docs/history/status-2026-11-07.md`, `docs/history/baseline-2026-11-06.md` | michaelatamuk |
| `README.md`, `CONTRIBUTING.md`, `SECURITY.md` | michaelatamuk |

## Offboarding

Where the sensitive material lives:

- model API key: environment variable on the PC; HUKS on device (planned);
- GitHub access: the maintainer account and the fork;
- Huawei developer account: the registered developer identity;
- signing keys: none created yet; store them in a hardware token when created;
- run records and screenshots: `.hopa/` on the PC, never in git.

Revoke access in this order: model key, GitHub token, signing key, Huawei
account. Rotate the model key first because it can spend money.
