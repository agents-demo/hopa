# A8 - sessions, approvals and sync

Date: 2026-11-13/14.

## Sessions and drafts

- `sessions`, `turns`, `run_records`, and since v3 `pending_approvals`.
- Titles from the first user message (40 chars), pinned first, then `updatedAt`;
  delete writes `deletedAt`, delete-all writes it for every row, `restore` brings
  a row back, so a deletion is a persisted tombstone. The selected conversation
  is persisted in DataStore.
- `RoomConversationStore.create()` reuses an empty `New chat` row instead of
  adding another (`SessionDao.draft()`), and the chat sheet hides empty sessions.

## Pending approvals

- Room v3 with `MIGRATION_2_3`; `UiApprovalGateway` persists the question while
  it waits, clears it after the answer, and denies after 120 s.
- `HopaApplication` clears a row found at startup: a question on disk means the
  process died while waiting, so the turn is gone and the question must not
  resurrect.
- `UiApprovalGatewayTest`: persist → resolve → clear; timeout → deny and clear.

## ChatSync

- `ChatSyncJson` speaks the bridge's `ChatStore` shape exactly:
  `id`, `title`, `titleAt`, `created`, `updated`, `deletedAt`,
  `turns[{id, role, text, at}]`.
- `ChatSync` pushes the whole local set (empty drafts excluded), adopts the
  merged snapshot, appends only unknown turns, and falls back to a plain pull
  when the push fails. A pushed live session that is missing from the snapshot
  is deleted locally — the tombstone exists on the server and must not be
  resurrected. A local tombstone is kept even if a live copy arrives.
- Settings: the same Keystore token feeds both `AdbDevice` and `ChatSync`.
- The Chats sheet has a sync action with a spinner and a result toast.

### Verified live (`emulator-5554`, bridge on 8901)

- Tapping sync logged `POST /chats` on the bridge and showed **Synced: 1 chats**
  in the app; the session list kept the current chat.
- Five unit cases cover: remote adoption, tombstone of a missing session,
  no resurrection, pull fallback, draft protection; plus a JSON round-trip.

## Still open

- Images (upload/download, cache, 4 MiB cap) and the two-device merge matrix
  (delete on A + edit on B, title conflict, id-less turns, rotation mid-sync).
- Sync is manual (the sheet action), not on app start or on change.
