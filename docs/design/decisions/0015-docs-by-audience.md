# ADR-0015 - Documentation is five folders, by audience

- Status: accepted
- Date: 2026-11-13

## Context

`docs/` had reached twelve folders, three of them holding one to three files
(`releases`, `status`, `contracts`). Each new platform or policy document added a
folder, and the reader had to know the genre before finding a file. The services
already have their own hemisphere (`services/docs`), so the app hemisphere had no
reason to keep growing horizontally.

## Decision

Five top-level folders, each answering one question:

| Folder | Answers |
|---|---|
| `design/` | what is it and why: `architecture/`, `decisions/` (ADR), `product/` |
| `guides/` | how to do it, per platform: `harmony/` today, `android/`, `windows/` later |
| `reference/` | what a thing is called: `contracts/`, bundles, glossary, policy |
| `project/` | how we run it: `plan/`, `status.md`, `operations/`, `releases/`, `archive/` |
| `media/` | pictures and clips |

Rules:

- A new **platform** adds a subfolder under `guides/` and one file under
  `design/architecture/`; it does not add a top-level folder.
- `design/decisions/` keeps one immutable file per decision; ADRs are nested, not
  merged into prose.
- `project/plan/` is the only active plan (`plan-status.py` defaults to it);
  retired plans stay in git by tag (ADR-0014).
- `project/archive/` is frozen evidence, not documentation.
- Service docs stay in `services/docs/` and mirror the same five genres.

## Consequences

- `docs/` has five folders, stable under Android and Windows.
- `plan-status.py` default path is `docs/project/plan`.
- The app index (`docs/README.md`) is a map of five folders; the service index is
  `services/docs/README.md`.

## Alternatives considered

- **Nine folders (keep `adr`, `contracts`, `releases`, `status`, `history`).**
  Rejected: the three tiny folders were the problem.
- **Diataxis (tutorials/how-to/reference/explanation).** Rejected: it splits
  `design` from `project` in ways that do not match how this repository is read.
- **One folder per app under `docs/apps/`.** Rejected: the app is not the axis;
  the genre is. Platform subfolders under `guides/` cover it.
