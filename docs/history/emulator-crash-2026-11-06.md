# Emulator freeze — 2026-11-06

Report: `crash_report-2026-11-06T082549.zip`
Type: **Guest No Response** (system freeze)

## Facts from the logs

| Item | Value |
|---|---|
| Host | Windows 11, x86_64 |
| GPU | Intel(R) Graphics, OpenGL ES 3.2 (driver 32.0.101.8826) |
| Host RAM | 32,245 MB total, 6,320 MB free at crash |
| Emulator | 6.1.1.200 |
| Guest | HarmonyOS 6.1.1(24), phone, 4 GB RAM |
| Host emulator peak | 3,132 MB |
| Guest memory peak | 0 (guest stopped reporting) |

Timeline (from `Emulator.log` and `kernel.log`):

- 08:24:33 — `hdc` disconnects; `hdc shell` starts failing.
- 08:25:13–08:25:49 — guest keep-alive delta grows 5 → 38 s.
- 08:25:49 — `Guest no response, delta: 38`; freeze recorded.
- 08:25:07 — `reboot.panic:SceneBoard exits 4times in 240000ms`.
- 08:25:16 — `Kernel panic - not syncing: sysrq triggered crash`.

## Root cause

The HarmonyOS **SceneBoard** process (the window/home UI) exited four times
inside four minutes. The guest's reboot policy then triggered a panic, which is
why the whole VM stopped answering.

Contributing signals:

- `ohos.sceneboard` repeatedly hit `avc: denied { ioctl }` on
  `/dev/access_token_id` (SELinux enforcing).
- GPU renderer errors: `real share context is NULL`,
  `not support transform_type 8`, repeated `slow child_event`.
- The crash server logged `memory is low` many times (1.3–2.5 GB free).

HOPA was not installed, so the app did not cause this.

## Fixes, in order

1. **Cold boot and wipe data** in DevEco Device Manager. Repeated SceneBoard
   crashes often come from a corrupt `userdata`/quick-boot state.
2. **Update the emulator** from 6.1.1.200 to the current 6.1.1.350+ patch.
3. **Free host RAM** — close Chrome/IDE/other VMs. 1.3 GB free is too low.
4. **Update the Intel graphics driver**, or switch the emulator to software
   rendering if the option is available.
5. **Use a physical phone for long bench runs.** The emulator is fine for a
   smoke test, not for a 30-minute unattended task battery.

## Status

After the panic the guest restarted. `hdc` connects again, but the emulator is
on its lock screen, so `uitest` still cannot read the screen. Unlock it before
running device tests.
