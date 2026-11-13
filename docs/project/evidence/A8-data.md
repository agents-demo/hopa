# A8 - sessions

Date: 2026-11-13. One item is complete: titles, pinning and ordering.

## Verified by reading the store

- `RoomConversationStore.create` makes a session titled `New chat`.
- The first user message replaces the title with its first 40 characters.
- `SessionDao.all` orders `pinned DESC, updatedAt DESC`; the chat sheet shows the
  current chat in its own `Current` section above the date groups.
- Delete writes `deletedAt`, delete-all writes it for every row, and `restore`
  brings a row back, so a deletion is a persisted tombstone, not a silent drop.
- The selected conversation is persisted in DataStore and re-selected on start.

## Not done in A8

- The schema has `sessions`, `turns` and `run_records` but no
  `pending_approvals`; approvals live in an in-process gateway.
- New chat always creates a row; it does not reuse one empty draft.
- No `ChatSync` (push, merge, pull fallback, tombstones across devices).
- No image upload/download or cache.
- No merge tests (resurrection, title conflict, id-less turns, rotation).
