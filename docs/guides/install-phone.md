# Install on a real phone

HOPA ships as a HarmonyOS **HAP**. HarmonyOS 6 does not install a HAP by
downloading it and tapping it. A phone installs HAPs through **AppGallery** or
through **hdc** with Developer mode enabled. This page is the honest map.

## What the GitHub release contains

- `HOPA-0.1.0-debug.hap` — the current app.
- It is signed with the **OpenHarmony debug kit**, and its profile embeds the
  **emulator's UDID**. A retail Huawei phone rejects it, even over `hdc`.
  It is intended for the emulator and OpenHarmony debug devices.

So the release is a **developer artifact**, not a tap-to-install package.

## Mate 80 (HarmonyOS 6): the paths that work

### A. AppGallery internal testing — the phone-only path

1. Use a Huawei developer account (AppGallery Connect).
2. Create the app with the bundle name `com.hopa.agent`.
3. Build a **release** `.app` signed with your AppGallery release certificate
   and profile, and upload it to **AppGallery Connect → Internal testing**.
4. Add your Huawei ID as a tester and install HOPA from **AppGallery** on the
   Mate 80.

Notes:

- This is the only path that needs no computer.
- The accessibility extension needs Huawei's approval for a retail build; until
  then HOPA cannot drive other apps on the phone.
- The app is ArkTS only; there is no APK.

### B. Wireless hdc from a computer — no cable, but a computer is required

1. On the phone: **Developer options → Wireless debugging**.
2. On a computer with the HarmonyOS SDK:

   ```bash
   hdc tconn <phone-ip>:<port>
   hdc shell bm get -u
   ```

3. Put that UDID into a **Huawei debug profile** (DevEco automatic signing with
   a Huawei account, or AppGallery Connect). The OpenHarmony debug profile in
   this repository is not trusted by a Huawei phone.
4. Sign the HAP with that profile and install:

   ```bash
   hdc install HOPA.hap
   ```

The release HAP will fail on a Mate 80 with a certificate or UDID error until
it is re-signed with a Huawei profile for that phone.

### C. Emulator or OpenHarmony debug board

Use the release HAP as-is: the profile UDID is the emulator's.

```bash
hdc install HOPA-0.1.0-debug.hap
```

## Verify the download

```text
SHA-256  46F90CCA04DA01700D228080A867DA6DA0E368A27C9AEA230BD96CA9818CB92A
```

## Why not a simple file install?

HarmonyOS does not expose an "unknown sources" installer for HAPs. Sideloading
is a developer flow (`hdc`), and retail distribution is AppGallery. This is a
platform rule, not a HOPA choice.
