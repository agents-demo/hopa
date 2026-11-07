# Versioning

Semantic versioning for three things, independently:

| Artefact | Version | Example |
|---|---|---|
| HAP / app | `MAJOR.MINOR.PATCH` | `0.1.0` |
| Brain service | `MAJOR.MINOR.PATCH` | `0.1.0` |
| Contracts (`contracts/schemas/`) | integer major + additive minor | `v1` |

## Contract rules

- Additive fields are allowed within `v1`.
- Removing or renaming a field requires `v2` and a golden-file update.
- A body rejects an unknown **major** and accepts a newer **minor**.
- Producers write `schemaVersion`; consumers must check it.

## App rules

- `MAJOR`: a change that breaks stored records or user-visible behaviour.
- `MINOR`: a new capability or a new contract field.
- `PATCH`: fixes, docs, performance.

## Records and migrations

A record carries `schemaVersion`. A reader must either migrate an old record or
refuse it with a clear error; it must never silently drop fields. Knowledge and
memory have their own versions and a rollback path.

## Deprecation

- Announce in the changelog.
- Keep the old path for at least one minor release.
- Remove only in the next major.

## Release tags

`app-vX.Y.Z`, `brain-vX.Y.Z`, `contracts-vN`. A release note lists the three
versions together.
