# A11 - inbound share target

Date: 2026-11-14.

The share target is the one inbound door into the composer. Android can hand HOPA
text, one image or one file; HOPA copies it, shows it and waits. Nothing is sent
until the user taps send.

## What the app accepts

| Share | Result |
|---|---|
| `ACTION_SEND` `text/plain` | the text waits in the composer |
| `ACTION_SEND` `image/*` | the image is copied, a thumbnail waits in the composer |
| `ACTION_SEND` `application/*` | the file is copied, a file chip waits in the composer |
| `ACTION_PROCESS_TEXT` | the selected text waits in the composer |
| `hopa://ask?text=` | the text waits in the composer |

All of them go through `MainActivity.goalFrom` / `intakeFrom`, so a share lands in
the same place whether the app was cold-started or already open
(`android:launchMode="singleTop"` + `onNewIntent`). The profile shells watch
`container.pendingAttachment` and switch to Chat, so a share from the power home
still shows up in the chat.

## The copy

`AttachmentIntake.accept(uri)`:

- reads the display name from `OpenableColumns`, falls back to `shared-file`;
- refuses at once when the provider declares more than 4 MiB;
- otherwise streams 8 KiB at a time into `files/attachments`, aborting the moment
  the running total passes 4 MiB and deleting the partial file;
- returns an `Attachment(name, mime, bytes, path)` or a notice
  (`TOO_LARGE` / `UNREADABLE`) that the composer shows in red.

The name is sanitised to `[A-Za-z0-9._-]` and shortened; the file name is prefixed
with the timestamp. One attachment is the rule: a second share replaces the
pending one and deletes the older copy, so no orphan bytes accumulate.

`AttachmentRules` owns the shared cap and the words: `Shared an image: <name>`,
`Shared a file: <name>`, `512 B`, `2 KB`, `1.5 MB`.

## Where the attachment lives

- `data/sessions/Attachment.kt`: name, mime, bytes, path.
- `ChatMessage.attachment` (nullable) - the turn the user sent.
- Room v5: `turns` gains `attachmentName`, `attachmentMime`, `attachmentBytes`,
  `attachmentPath`; `MIGRATION_4_5` adds them with defaults.
- `ConversationMapper` reads and writes them, so a reopened chat still shows the
  image.
- `RoomConversationStore.adopt` keeps the local attachment when a synced snapshot
  arrives without one: `ChatSync` still carries text only, and a sync must not
  erase the picture on the phone that has it.

## The composer and the bubble

- `PendingAttachmentRow`: 56 dp thumbnail for images, a file chip otherwise, the
  name and `size · mime`, and a remove button that deletes the copied bytes.
- The composer's send button is enabled when there is text **or** an attachment;
  the placeholder becomes "Add a note…".
- The bubble renders the attachment above the caption (`AttachmentPreview`,
  decoded at `inSampleSize = 2` off the main thread).
- A captionless send uses `AttachmentRules.describe`, so the chat, the title and
  the synced text all still say what happened.

## Build and tests

```
cd apps/android
gradlew.bat :app:testDebugUnitTest :app:assembleDebug
```

`AttachmentRulesTest` covers the cap, the image/file split, the two captionless
sentences and the size words.

## Live check

Host: Windows; `emulator-5554`, API 35; debug APK from this tree.

HOPA is registered as a share target: `cmd package query-activities -a
android.intent.action.SEND -t image/png` (and `-t application/pdf`) lists
`com.hopa.app.MainActivity` in `com.hopa.android`.

The adb shell cannot hand over a MediaStore URI - a grant comes from the sending
app, not from `am`:

```
E DatabaseUtils: java.lang.SecurityException: com.hopa.android has no access to
  content://media/external/images/media/1000000018
```

So the positive run delivered the same intent with a `file://` URI of a copy in
HOPA's own storage, which exercises the same `contentResolver.openInputStream`
path; the app falls back to `intent.type` for the MIME when the provider has no
type (as with `file://`).

1. **Cold start with the share** - the app was force-stopped, then the `SEND`
   intent launched it. HOPA opened on the **Chat** tab (although the profile is
   Power) and the composer showed the pending row: thumbnail, `shared-file`,
   `3 KB · image/png`, and a remove button
   (`docs/media/android-share-composer.png`). `onCreate` copies the stream only
   when `savedInstanceState == null`, so a rotation does not duplicate it.
2. **Send without a caption** - the bubble shows the image above
   `Shared an image: shared-file`, the composer cleared, the list came to rest
   with the caption fully visible, and the demo model answered
   (`docs/media/android-share-sent.png`).
3. `run-as com.hopa.android ls -l files/attachments` lists the copies
   (`1794647547740-shared-file`, `1794648617225-shared-file`), 4007 bytes each -
   the bytes are on disk.
4. **Restart** (`am force-stop` + `am start`), then reopen the chat: the image
   and its caption are still there. Room v5 wrote and read the four attachment
   columns back.
5. **A second share while one was pending** replaced it and deleted the older
   pending copy; `files/attachments` went back to one file.
6. **A share the app cannot read** leaves the red
   `HOPA could not read that file.` under the composer, deletes the partial
   copy, and still lands on Chat
   (`docs/media/android-share-refused.png`).

`gradlew.bat :core:check :capabilities:testDebugUnitTest :app:testDebugUnitTest
:app:assembleDebug` is green.


## Fixed on the way

- The Power home and Easy history bottom bars sat under the system navigation
  bar; both now take `navigationBarsPadding()`.
- The chat list stopped short of the last bubble when a tall attachment bubble
  arrived; it now scrolls once more after the next measure.

## Limits (honest)

- **Attachments stay local.** The bridge has no upload/download endpoint yet
  (A8 images), so `ChatSync` syncs the sentence and not the bytes. The turn keeps
  its picture on the phone that received it.
- One attachment, 4 MiB: taken from the plan's shared caps, not invented.
