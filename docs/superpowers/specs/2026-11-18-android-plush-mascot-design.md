# Android and Windows plush mascot — design

Date: 2026-11-18
Status: approved (Android); Windows added on request
Scope: `apps/android` and `apps/windows`. Harmony is untouched.

## Intent

Replace the HOPA mascot — currently a coral phone drawn in Compose and a laptop
vector drawn in XAML — with the supplied orange plush character, both as the app
icon and as the avatar in chats. Make it feel alive in the way digitalmate-web's
BeeBou does, without shipping a video or a frame-by-frame animation pipeline.

Why: the plush reads warmer and more like a companion than the abstract phone,
and Android and Windows are the active clients. The app icon is the first thing a
user sees; the chat avatar is what they spend time with.

## Goals

- The Android launcher icon is the plush, as a proper adaptive icon (legacy
  densities, monochrome themed icon, correct safe zone).
- The Windows executable and every window carry the plush as their icon.
- Every mascot call site renders the plush: Android chat hero (76 dp), answer
  avatar (26 dp), thinking indicator (20 dp), capabilities (46 dp), error (20 dp);
  Windows header (26 px), empty state (108 px) and answer avatar (22 px).
- The plush is visibly alive: float, breathe, blink, and react to state.
- One script regenerates every Android and Windows asset from a committed source
  image.
- Respect the existing static/`animate = false` contract and the system animation
  setting.

## Non-goals

- Harmony. No shared mascot component changes outside Android and Windows.
- No animated WebP/GIF/Lottie, no video, no new runtime dependency.
- No background removal or cut-out of the fur.
- No copy, layout or navigation changes.

## Anti-goals

- A ragged cut-out edge where the fur meets the background.
- A figure that shimmers or changes between frames (AI-edited full frames).
- A static portrait with no motion — that would not be more live.
- A face or waving arm clipped by the launcher mask.

## Constraints

- Source: the supplied 473 x 1024 portrait JPEG, cream studio background with a
  soft contact shadow and the right arm raised.
- Android adaptive icons: 108 dp canvas, 66 dp safe zone, legacy 48 dp rasters.
- Compose minSdk 29; the project has no image-loading library and should not gain
  one. Standard Compose animation APIs are available.
- WPF/.NET 8: no GIF animation library is present and none will be added. WPF
  transforms, `DispatcherTimer` and `DoubleAnimation` are available.
- `tools/scripts/make-icon.py` already requires Pillow and numpy; generation stays
  on that documented stack, and its tests join the existing `pytest tools/scripts`
  CI step (the Python job gains Pillow and numpy).
- Android and Windows will diverge from Harmony's phone mark. The repo-level
  README still describes the phone; updating it is out of scope and noted as a
  known divergence.

## Approaches considered

**A. Living rig on the still photo (chosen).** Keep the photo as a crisp
rounded-square badge and animate it with platform transforms: float, breathe,
blink via a second locally edited frame, state reactions, tap wiggle. No new
dependency, sharp at 20 dp, small binary cost, deterministic art.

**B. Pre-rendered animated WebP, BeeBou parity.** Generate idle/working loops and
decode them with `ImageDecoder` / `AnimatedImageDrawable` on Android; Windows
would need custom frame decoding. Most faithful to digitalmate, but from a single
still the frames must be synthesised (warp, blink, arm motion), files cost
0.5–1 MB each, and the detail is lost at 20–26 dp. Worth revisiting only if a
short clip of the plush appears.

**C. Static photo with the existing gentle bob.** Cheapest, but fails the
"more live" goal.

A was picked because it delivers the visible behaviour of B without synthetic
video, extra codecs, or asset weight.

## Design

### Source and generation

- Commit the supplied photo at `tools/assets/hopa-plush-2026.jpg`.
- Rewrite `tools/scripts/make-icon.py` to own the Android and Windows assets and
  read that photo. It writes:
  - `mipmap-{mdpi..xxxhdpi}/ic_launcher.png` — legacy 48 dp rasters.
  - `mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png` — 108 dp adaptive
    foreground, photo composed on the cream field.
  - `drawable-nodpi/hopa_plush.png` / `hopa_plush_blink.png` — 512 px avatar and
    closed-eye frame.
  - `apps/windows/Hopa.Windows/Assets/mascot.png` / `mascot-blink.png` — 512 px
    avatars for WPF.
  - `apps/windows/Hopa.Windows/Assets/hopa.ico` — 16, 24, 32, 48, 64, 128 and
    256 px squircle icon.
  - `docs/media/hopa-plush-2026.png` — 512 px store/docs raster.
- Crop: square 462 px at `(0, 274)` in the source. It contains the whole figure
  (saturated bbox 10..441 x 306..703) with a few pixels of air.
- Icon composition: a cream `#F7F1E6` field (the photo's own background colour)
  with the crop at 47% of the canvas, feathered a few pixels into the field. The
  figure's farthest point (the raised hand) sits about 31.8 dp from the centre,
  inside the 66 dp safe circle; the figure spans about 47 dp.

- The blink frame is edited locally: each eye is covered with fur sampled around
  it and a dark closed-eye curve is drawn. The rest of the pixels are untouched,
  so no flicker.

### Android launcher icon

- `mipmap-anydpi-v26/ic_launcher.xml` keeps its structure: cream background
  colour, photo foreground, monochrome layer. The background colour changes to
  `#F7F1E6` so the foreground's feathered edge is invisible and launcher parallax
  does not reveal a seam.
- `ic_launcher_monochrome.xml` is replaced by a hand-drawn silhouette (round
  body, two antennae, two feet, raised right arm) inside the safe zone.
- `AndroidManifest` keeps `android:icon` / `android:roundIcon` pointing at
  `@mipmap/ic_launcher`. The Android 12 splash picks the same icon.
- Legacy icons are opaque and square; launchers apply their own mask.

### Windows icon and mark

- `Hopa.Windows.csproj` gains `<ApplicationIcon>Assets\hopa.ico</ApplicationIcon>`
  and resource entries for the new assets. Each of the five windows gains
  `Icon="Assets/hopa.ico"`.
- A new `Chat/HopaMark` user control shows the avatar, clips it to a 20%
  rounded square, and owns the idle motion:
  - float: `TranslateTransform.Y` 0 → -2.2 px, 2.4 s each way, forever;
  - breathe: `ScaleY` 1 → 1.025 and `ScaleX` 1 → 0.99, 2.4 s each way;
  - blink: `Blink` image opacity 0 → 1 for 150 ms every 4.2 s;
  - `IsStatic` stops timers and animations for transcript avatars;
  - `SystemParameters.ClientAreaAnimation == false` disables motion.
- `MainWindow.xaml` replaces `LaptopMarkTemplate` with the control at 26 px
  (header, static), 108 px (empty state, live) and 22 px with `IsStatic` (answer
  avatar). The old template is deleted.
- The same control handles the Windows avatar; no second image path.

### Avatar and motion (Android)

`HopaMascot` keeps its public API (`sizeDp`, `state`, `animate`, `interactive`)
and its call sites, but its Canvas is replaced by:

- the `hopa_plush` asset clipped to a 20% rounded square, with a soft shadow;
- a crossfade to `hopa_plush_blink` for 150 ms every 4200 ms when the avatar is
  at least 32 dp and motion is on;
- a float of 2% of the avatar height every 2400 ms (4.8 s cycle);
- a breathe scale of 1.00 → 1.03 vertically and 0.99 horizontally.

A rounded square, not a circle: the raised arm sits in the top-right corner and a
circle would cut the hand. The badge still reads as an app-icon tile.

State mapping, aligned with today's behaviour:

| state | motion |
| --- | --- |
| idle / waiting | float + breathe + blink |
| thinking / acting | 520 ms opacity pulse; acting leans -4° |
| listening | leans -2° |
| happy | 1.06 scale, short settle |
| error | 0.65 opacity |
| tap | two ±3° wiggles, then the existing "Hi, I'm HOPA 👋" bubble |

`animate = false` freezes all motion (transcripts stay still). When the Android
animator duration scale is zero, the blink loop is skipped.

### Verification

- `pytest tools/scripts/test_make_icon.py -v`.
- `cd apps/android && .\gradlew.bat :app:assembleDebug`.
- `python tools/scripts/android-smoke.py --serial emulator-5554` installs and
  captures the app on the running emulator.
- `dotnet build apps/windows/Hopa.Windows/Hopa.Windows.csproj` and
  `dotnet test apps/windows/Hopa.Windows.Tests/Hopa.Windows.Tests.csproj`.
- `Hopa.Windows.exe --shot-frame docs/media/windows-plush-empty.png` captures the
  Windows empty state.
- Check on device: app-info icon under squircle and circle masks, themed icon,
  empty-state hero, answer avatar, thinking indicator, tap bubble; on Windows:
  taskbar/exe icon, header mark, empty state, answer avatar.
- Add `docs/project/evidence/plush-mark-2026-11-18.md` with the screenshots,
  commands and the before/after.

### Docs

- Update the launcher-icon section of `docs/guides/android/release.md` (source,
  outputs, safe zone, monochrome).
- Evidence doc as above, including the deliberate Android/Windows/Harmony
  divergence.

## Left to the builder

- Exact feather radius, blink-eye drawing and monochrome path data; tune on
  device.
- Final timings, and whether happy earns a one-shot hop in addition to the scale.
- Whether the 20 dp thinking avatar should blink at all (it may read as a flicker);
  the design defaults to no blink below 32 dp.

## Provenance

The photo is user-supplied. It is recorded in the evidence doc; no third-party
code is copied, so `NOTICE` is unchanged.
