# UX specification

Status: **shell only.** The ArkUI project has four tabs. The behaviour below is
the target, not what is implemented.

## Screens

| Screen | Purpose | State |
|---|---|---|
| Chat | Ask for a task; see steps and the answer | placeholder |
| Tasks | Progress, current action, stop, takeover | placeholder |
| Approval | Amount, merchant, consequence, deny | not built |
| Memory | Runs, learned notes, skills, delete | placeholder |
| Settings | Model, key, network, a11y, sandbox, retention | partial |
| Onboarding | What it can and cannot do; permissions | not built |

## States

Every screen needs:

- empty (first run, no tasks);
- loading (capturing, thinking, acting);
- running (step N, current action, live thumbnail);
- waiting for approval;
- waiting for the user (2FA, CAPTCHA, login);
- success;
- failure with retry / edit / hand over / abort;
- offline and model-unavailable.

## Trust UX

- "Why did HOPA do that?" explains every step.
- A timeline shows step, action, result and screenshot.
- Pause and stop are always one tap away.
- The approval sheet is screen-reader accessible and respects font scale.
- Cost and token use are visible per run and per day.
- The model and fallback state are visible.
- Lock-screen notifications hide task details.
- A Quick Settings tile or shortcut stops the agent.

## What HOPA cannot do

Onboarding must state plainly:

- no background screen and no virtual display;
- no operation while the user is using the phone;
- no payment without approval;
- no CAPTCHA or password handling;
- no control of other apps until the accessibility service is enabled and the
  ACL is approved.

## Accessibility of HOPA itself

- Screen-reader labels on every control.
- Contrast at least 4.5:1 for body text.
- Font scale up to 200% without clipping.
- No colour-only status.
- Reduced-motion support.

## i18n and theme

- English and Chinese at launch.
- Dark mode from the system.
- Dates, numbers and currency use the locale.
- Right-to-left is a future check.

## Budgets

| Budget | Target |
|---|---|
| Cold start | < 2 s |
| HAP size | to be set after the first release build |
| Memory | to be measured under a 30-step task |
| Network | no calls unless the task needs them |

## Beta

Ten beta users, a feedback log, and a fix before each release. Not started.
