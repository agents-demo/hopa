# Plush Mascot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the HOPA phone mascot with the supplied orange plush on Android and Windows, as the app icon and as a living chat avatar.

**Architecture:** One Python generator reads the committed photo and writes every icon, avatar and blink frame for both clients. Android animates the still in Compose; Windows animates it in a small WPF `HopaMark` control. No animated image formats or new runtime dependencies.

**Tech Stack:** Python 3.12 + Pillow + numpy, Android Compose (Kotlin), WPF (.NET 8, C#/XAML), pytest.

**Spec:** `docs/superpowers/specs/2026-11-18-android-plush-mascot-design.md`

## Global Constraints

- Source image: the user-supplied 473 x 1024 JPEG, committed at `tools/assets/hopa-plush-2026.jpg`.
- Crop: square 462 px at `(0, 274)` from the source.
- Field colour: `#F7F1E6` (RGB 247, 241, 230), the photo's own background.
- Adaptive icon: 108 dp canvas, 66 dp safe circle, legacy 48 dp rasters; figure's farthest point ≤ 33 dp from centre.
- Icon composition: crop at 47% of the canvas. Avatar badge radius: 20% of the edge.
- Avatar/blink assets: 512 x 512. Windows ICO sizes: 16, 24, 32, 48, 64, 128, 256.
- No animated WebP/GIF/Lottie; no new runtime dependency; no fur cut-out.
- Blink: 150 ms every 4200 ms, only at ≥ 32 dp and only when motion is on.
- Idle: 2.4 s each way float (2% of size) and breathe (scaleY 1.03, scaleX 0.99).
- `animate = false` / `IsStatic = true` freezes transcripts. Android animator scale 0 and WPF `SystemParameters.ClientAreaAnimation == false` disable motion.
- Harmony is untouched.
- Windows builds need the .NET 8 SDK. If `dotnet --version` fails, install it with `winget install --id Microsoft.DotNet.SDK.8 -e` before Task 4.

## Review Focus

- **Launcher masks (circle, squircle, round-rect) and the 16 px Windows icon:** the raised hand stays visible and the plush is still legible; the figure must not cross the 33 dp radius.
- **Reduced motion:** animator scale 0 on Android and `ClientAreaAnimation == false` on Windows leave a still badge with no timers running.
- **Small sizes (20–26 dp / 22 px):** the badge reads as the plush, the blink does not flicker, and the shadow does not muddy the face.
- **Dark launchers and dark desktop themes:** the cream badge has no transparent gaps and no seam where the foreground meets the background.
- **Windows DPI 125–200%:** the clip radius and the two image layers stay aligned, with no corner sliver.

---

### Task 1: Asset generator and its tests

**Files:**
- Create: `tools/assets/hopa-plush-2026.jpg` (copy of the supplied photo)
- Create: `tools/scripts/test_make_icon.py`
- Modify: `tools/scripts/make-icon.py` (full rewrite)
- Modify: `.github/workflows/ci.yml` (add Pillow and numpy to the Python job's install line)

**Interfaces:**
- Produces, in module `make_icon`:
  - `SOURCE: Path`, `CROP: tuple[int, int, int, int]`, `FIELD: tuple[int, int, int]`, `ICON_FRACTION: float`, `BADGE_RADIUS: float`
  - `load_source(path: Path = SOURCE) -> Image.Image`
  - `square_crop(image: Image.Image) -> Image.Image`
  - `compose_icon(size: int) -> Image.Image`
  - `blink_frame(image: Image.Image) -> Image.Image`
  - `apply_badge_mask(image: Image.Image) -> Image.Image`
  - `write_all(root: Path = ROOT) -> list[Path]`

- [ ] **Step 1: Copy the source photo**

```powershell
New-Item -ItemType Directory -Force tools/assets
Copy-Item "C:\Users\a00644753\Downloads\WhatsApp Image 2026-11-18 at 15.58.55.jpeg" tools/assets/hopa-plush-2026.jpg
```

- [ ] **Step 2: Write the failing tests**

Create `tools/scripts/test_make_icon.py`:

```python
"""Tests for the plush icon and avatar generator."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "make-icon.py"


def _module():
    spec = importlib.util.spec_from_file_location("make_icon", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _saturated(image: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    data = np.asarray(image.convert("RGB")).astype(np.float32) / 255.0
    high = data.max(axis=2)
    low = data.min(axis=2)
    sat = np.where(high > 0, (high - low) / np.maximum(high, 1e-6), 0)
    return np.nonzero((sat > 0.18) & (high > 0.25))


def test_square_crop_contains_the_figure() -> None:
    module = _module()
    crop = module.square_crop(module.load_source())
    assert crop.size == (462, 462)
    ys, xs = _saturated(crop)
    assert abs(int(xs.min()) - 10) <= 2
    assert abs(int(ys.min()) - 32) <= 2
    assert abs(int(xs.max()) - 441) <= 2
    assert abs(int(ys.max()) - 429) <= 2


def test_icon_keeps_the_figure_in_the_safe_circle() -> None:
    module = _module()
    icon = module.compose_icon(108)
    ys, xs = _saturated(icon)
    radius = float(np.sqrt((xs - 54.0) ** 2 + (ys - 54.0) ** 2).max())
    assert radius <= 34.0
    assert int(xs.max() - xs.min()) >= 40


def test_blink_diff_is_confined_to_the_eyes() -> None:
    module = _module()
    base = module.square_crop(module.load_source())
    blink = module.blink_frame(base)
    diff = np.abs(np.asarray(base, np.int16) - np.asarray(blink, np.int16)).sum(axis=2) > 8
    ys, xs = np.nonzero(diff)
    assert ys.size > 50

    def inside(x: int, y: int, box: tuple[int, int, int, int]) -> bool:
        left, top, right, bottom = box
        return left <= x <= right and top <= y <= bottom

    left_eye = (160, 146, 212, 204)
    right_eye = (256, 146, 308, 204)
    assert all(inside(int(x), int(y), left_eye) or inside(int(x), int(y), right_eye)
               for x, y in zip(xs, ys))


def test_outputs_have_expected_sizes(tmp_path: Path) -> None:
    module = _module()
    module.write_all(tmp_path)
    android = tmp_path / "apps" / "android" / "app" / "src" / "main" / "res"
    windows = tmp_path / "apps" / "windows" / "Hopa.Windows" / "Assets"
    assert Image.open(android / "mipmap-mdpi" / "ic_launcher.png").size == (48, 48)
    assert Image.open(android / "mipmap-xxxhdpi" / "ic_launcher.png").size == (192, 192)
    assert Image.open(android / "mipmap-mdpi" / "ic_launcher_foreground.png").size == (108, 108)
    assert Image.open(android / "drawable-nodpi" / "hopa_plush.png").size == (512, 512)
    assert Image.open(android / "drawable-nodpi" / "hopa_plush_blink.png").size == (512, 512)
    assert Image.open(windows / "mascot.png").size == (512, 512)
    ico = Image.open(windows / "hopa.ico")
    assert {(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)} <= ico.info["sizes"]
```

- [ ] **Step 3: Run the tests and watch them fail**

Run: `python -m pytest tools/scripts/test_make_icon.py -v`
Expected: collection error or `AttributeError` because `make_icon` is still the old vector script.

If pytest is missing: `python -m pip install --user pytest`.

- [ ] **Step 4: Rewrite `tools/scripts/make-icon.py`**

Implement the interfaces above. Keep the implementation specific:

- `CROP = (0, 274, 462, 736)`, `FIELD = (247, 241, 230)`, `ICON_FRACTION = 0.47`, `BADGE_RADIUS = 0.20`.
- `compose_icon(size)`: RGBA canvas filled with `FIELD`; scale the crop to `round(size * 0.47)` with LANCZOS; paste it centred with a feathered mask (rectangle inset by `max(1, side // 24)`, Gaussian blur of that inset).
- `blink_frame(image)`: copy the crop; for each eye centre `(186, 175)` and `(282, 175)`, sample a 32 x 32 patch from the cheek beside that eye (right cheek for the left eye, left cheek for the right eye), paste it over the eye, then draw a downward arc `(cx-13, cy-8, cx+13, cy+8)`, start 20°, end 160°, width 4, colour `(28, 27, 24, 255)`.
- `apply_badge_mask(image)`: set alpha from a rounded rectangle covering the image with radius `round(min(w, h) * 0.20)`.
- `write_all(root)` creates every parent directory and writes:
  - `apps/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` at 48/72/96/144/192 px.
  - the same folders' `ic_launcher_foreground.png` at 108/162/216/324/432 px.
  - `drawable-nodpi/hopa_plush.png` and `hopa_plush_blink.png`, 512 px from the crop.
  - `apps/windows/Hopa.Windows/Assets/mascot.png` and `mascot-blink.png`, 512 px from the crop.
  - `apps/windows/Hopa.Windows/Assets/hopa.ico` from a 256 px `apply_badge_mask(compose_icon(256))` with `sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]`.
  - `docs/media/hopa-plush-2026.png`, 512 px from the crop.
  - Print every written path.
- `main()` calls `write_all(ROOT)`.

- [ ] **Step 5: Add the generation dependencies to CI**

In `.github/workflows/ci.yml`, in the `python` job's "Install packages" step, append `"Pillow>=10" "numpy>=1.26"` to the pip install line.

- [ ] **Step 6: Run the tests and make them pass**

Run: `python -m pytest tools/scripts/test_make_icon.py -v`
Expected: 4 passed.

- [ ] **Step 7: Generate the assets**

Run: `python tools/scripts/make-icon.py`
Expected: 16 printed paths, no errors. Check `git status` shows the regenerated mipmaps, the new avatars, the ICO and the docs raster.

- [ ] **Step 8: Commit**

```bash
git add tools/assets tools/scripts/make-icon.py tools/scripts/test_make_icon.py .github/workflows/ci.yml apps/android/app/src/main/res apps/windows/Hopa.Windows/Assets docs/media/hopa-plush-2026.png
git commit -m "feat(design): generate the plush mark for Android and Windows"
```

---

### Task 2: Android adaptive icon

**Files:**
- Modify: `apps/android/app/src/main/res/values/colors.xml`
- Modify: `apps/android/app/src/main/res/drawable/ic_launcher_monochrome.xml`
- Verify: `apps/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (structure stays)

**Interfaces:**
- Consumes: the `ic_launcher.png` and `ic_launcher_foreground.png` files from Task 1.
- Produces: an adaptive icon whose background matches the foreground field and whose monochrome layer is the plush silhouette.

- [ ] **Step 1: Match the background colour to the photo field**

In `values/colors.xml`, change `ic_launcher_background` from `#F7F4EE` to `#F7F1E6`.

- [ ] **Step 2: Replace the monochrome silhouette**

Replace the `<group>` content of `drawable/ic_launcher_monochrome.xml` with a 108 x 108 viewport and these black paths:

```xml
<path android:fillColor="#000000"
      android:pathData="M54,34C66,34 76,44 76,58C76,71 66,80 54,80C42,80 32,71 32,58C32,44 42,34 54,34Z" />
<path android:fillColor="#000000"
      android:pathData="M36,32a4,4 0 1,0 8,0a4,4 0 1,0 -8,0z" />
<path android:fillColor="#000000"
      android:pathData="M64,32a4,4 0 1,0 8,0a4,4 0 1,0 -8,0z" />
<path android:fillColor="#000000"
      android:pathData="M45,76h8a3,3 0 0 1 3,3v2a3,3 0 0 1 -3,3h-8a3,3 0 0 1 -3,-3v-2a3,3 0 0 1 3,-3z" />
<path android:fillColor="#000000"
      android:pathData="M57,76h8a3,3 0 0 1 3,3v2a3,3 0 0 1 -3,3h-8a3,3 0 0 1 -3,-3v-2a3,3 0 0 1 3,-3z" />
<path android:fillColor="#000000" android:strokeColor="#000000"
      android:strokeWidth="6" android:strokeLineCap="round"
      android:pathData="M72,58L81,47" />
<path android:fillColor="#000000" android:strokeColor="#000000"
      android:strokeWidth="6" android:strokeLineCap="round"
      android:pathData="M36,60L31,70" />
```

Remove the old `<group>` wrapper and its scale/translate.

- [ ] **Step 3: Build the app**

Run: `cd apps/android && .\gradlew.bat :app:assembleDebug`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Commit**

```bash
git add apps/android/app/src/main/res/values/colors.xml apps/android/app/src/main/res/drawable/ic_launcher_monochrome.xml
git commit -m "feat(android): make the plush the launcher icon"
```

---

### Task 3: Android living avatar

**Files:**
- Modify: `apps/android/app/src/main/kotlin/com/hopa/app/ui/component/HopaMascot.kt`

**Interfaces:**
- Keeps: `fun HopaMascot(modifier: Modifier = Modifier, sizeDp: Dp = 92.dp, state: String = "idle", animate: Boolean = true, interactive: Boolean = true)`.
- Consumes: `R.drawable.hopa_plush`, `R.drawable.hopa_plush_blink` from Task 1.
- Produces: the same composable, now rendering and animating the plush.

- [ ] **Step 1: Replace the Canvas with the photo and the idle motion**

Keep the existing public signature, bubble drawing, `bubblePath`, tap haptics, bubble text and accessibility label. Replace the drawing and motion with:

- `@Composable private fun rememberIdleMotion(animate: Boolean): IdleMotion`, returning `IdleMotion(float = 0f, breathe = 0f)` when `!animate`; otherwise a `rememberInfiniteTransition` with two floats:
  - `float`: -1f → 1f, `tween(2400, easing = EaseInOut)`, `RepeatMode.Reverse`;
  - `breathe`: 0f → 1f, same spec.
- `@Composable private fun rememberBlink(enabled: Boolean): Boolean` using `LaunchedEffect(enabled)`: when enabled, loop `delay(4200); blink = true; delay(150); blink = false`.
- `animationsOn = animate && Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f`, read once with `LocalContext.current` and `android.provider.Settings` through `remember`.
- Blink is enabled only when `animationsOn && sizeDp >= 32.dp`.
- The outer modifier: `.size(sizeDp)`, then `.offset(y = if (state == "idle" || state == "waiting") sizeDp * 0.02f * float else 0.dp)`, then `.scale(x = 1f - 0.01f * breathe, y = 1f + 0.03f * breathe)`, then `.graphicsLayer(rotationZ = tilt + wiggle.value, alpha = alpha)`, then `.shadow(elevation = 3.dp, shape = badge, clip = false)`, then `.clip(badge)`, then `.clickable(...)`.
- `val badge = RoundedCornerShape(sizeDp * 0.20f)`.
- Inside the Box: `Image(painterResource(R.drawable.hopa_plush), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())`; always place the blink image on top with `alpha = blinkAlpha`, where `val blinkAlpha by animateFloatAsState(if (blink) 1f else 0f, tween(60), label = "blink")`.
- Tap behaviour: existing cheer (1.06 scale), existing bubble, plus a wiggle: an `Animatable(0f)` that animates to 3f, -3f, 0f in three 90 ms `tween`s inside the click coroutine. Combine `tilt + wiggle.value` in `rotationZ`.
- Keep `alpha`: 0.65 for error, 0.88 while pulsing, else 1. Keep `tilt`: -4 for acting, -2 for listening, else 0.
- Add `Modifier.semantics { contentDescription = label() }` to the outer Box.

- [ ] **Step 2: Build**

Run: `cd apps/android && .\gradlew.bat :app:assembleDebug`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add apps/android/app/src/main/kotlin/com/hopa/app/ui/component/HopaMascot.kt
git commit -m "feat(android): animate the plush in chats"
```

---

### Task 4: Windows icon and living mark

**Files:**
- Create: `apps/windows/Hopa.Windows/Chat/HopaMark.xaml`
- Create: `apps/windows/Hopa.Windows/Chat/HopaMark.xaml.cs`
- Modify: `apps/windows/Hopa.Windows/Shell/MainWindow.xaml`
- Modify: `apps/windows/Hopa.Windows/Dialogs/ApprovalWindow.xaml`, `Dialogs/RenameWindow.xaml`, `Dialogs/SettingsWindow.xaml`, `Dialogs/RunDetailsWindow.xaml`
- Modify: `apps/windows/Hopa.Windows/Hopa.Windows.csproj`

**Interfaces:**
- Consumes: `Assets/mascot.png`, `Assets/mascot-blink.png`, `Assets/hopa.ico` from Task 1.
- Produces: `Hopa.Windows.Chat.HopaMark`, a `UserControl` with a `bool IsStatic` dependency property (default `false`).

- [ ] **Step 1: Add the control**

`Chat/HopaMark.xaml`:

```xml
<UserControl x:Class="Hopa.Windows.Chat.HopaMark"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Grid x:Name="Surface" RenderTransformOrigin="0.5,0.5">
        <Grid.RenderTransform>
            <TransformGroup>
                <ScaleTransform x:Name="Breathe" ScaleX="1" ScaleY="1" />
                <TranslateTransform x:Name="Float" Y="0" />
            </TransformGroup>
        </Grid.RenderTransform>
        <Image x:Name="Base" Source="pack://application:,,,/Assets/mascot.png" Stretch="UniformToFill" />
        <Image x:Name="Blink" Source="pack://application:,,,/Assets/mascot-blink.png"
               Stretch="UniformToFill" Opacity="0" />
    </Grid>
</UserControl>
```

`Chat/HopaMark.xaml.cs` implements:

- `public static readonly DependencyProperty IsStaticProperty` with a `PropertyChangedCallback`.
- `Loaded`/`Unloaded` handlers and `SizeChanged`:
  - `Surface.Clip = new RectangleGeometry(new Rect(0, 0, w, h), w * 0.20, h * 0.20)`.
- `StartMotion()` only when `!IsStatic && SystemParameters.ClientAreaAnimation`:
  - `DoubleAnimation` on `Float.Y`: 0 → -2.2, 2400 ms, `AutoReverse`, `RepeatBehavior.Forever`, `SineEase` in/out.
  - `DoubleAnimation` on `Breathe.ScaleY`: 1 → 1.025; on `Breathe.ScaleX`: 1 → 0.99; same timing.
  - `DispatcherTimer` every 4200 ms sets `Blink.Opacity = 1` and starts a 150 ms one-shot timer that sets it back to 0.
- `StopMotion()` clears the animations (`BeginAnimation(..., null)`) and stops both timers.
- `IsStatic` changes and `Loaded`/`Unloaded` call `StopMotion()` then `StartMotion()`.

- [ ] **Step 2: Use it in the main window**

In `Shell/MainWindow.xaml`:

- Add `xmlns:chat="clr-namespace:Hopa.Windows.Chat"` to the `<Window>` element.
- Delete the `LaptopMarkTemplate` `ControlTemplate`.
- Header: replace the 26 px `<Control Template=...>` with `<chat:HopaMark Width="26" Height="26" IsStatic="True" Margin="0,0,12,0" VerticalAlignment="Center" />`. The header stays still; only the empty state breathes.
- Empty state: replace the 108 px `<Control Template=...>` with `<chat:HopaMark Width="108" Height="108" />`.
- Message template: replace `<Image x:Name="Mark" Source="Assets/mascot.png" ... />` with `<chat:HopaMark x:Name="Mark" Width="22" Height="22" IsStatic="True" Margin="0,1,12,0" VerticalAlignment="Top" Visibility="Collapsed" />`. Keep the `DataTrigger` targeting `Mark`.

- [ ] **Step 3: Set the app icon**

- In `Hopa.Windows.csproj`, add `<ApplicationIcon>Assets\hopa.ico</ApplicationIcon>` to the first `PropertyGroup`, and add `<Resource Include="Assets\mascot-blink.png" />` and `<Resource Include="Assets\hopa.ico" />` beside the existing `mascot.png` resource.
- Add `Icon="Assets/hopa.ico"` to the `<Window>` root of `Shell/MainWindow.xaml`, `Dialogs/ApprovalWindow.xaml`, `Dialogs/RenameWindow.xaml`, `Dialogs/SettingsWindow.xaml` and `Dialogs/RunDetailsWindow.xaml`.

- [ ] **Step 4: Build and test**

Run: `dotnet build apps/windows/Hopa.Windows/Hopa.Windows.csproj`
Expected: `Build succeeded`.

Run: `dotnet test apps/windows/Hopa.Windows.Tests/Hopa.Windows.Tests.csproj`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/windows/Hopa.Windows
git commit -m "feat(windows): plush icon and living header mark"
```

---

### Task 5: Verify on both apps and document

**Files:**
- Create: `docs/project/evidence/plush-mark-2026-11-18.md`
- Create: `docs/media/android-plush-home-2026-11-18.png`
- Create: `docs/media/android-plush-icon-2026-11-18.png`
- Create: `docs/media/windows-plush-empty-2026-11-18.png`
- Modify: `docs/guides/android/release.md` (launcher-icon section)

**Interfaces:**
- Consumes: the built APK and the built Windows app from Tasks 3 and 4.
- Produces: evidence screenshots and accurate docs.

- [ ] **Step 1: Install and capture Android**

Run: `python tools/scripts/android-smoke.py --serial emulator-5554 --out docs/media/android-plush-home-2026-11-18.png`
Expected: a screenshot of the empty state with the plush hero.

Open the app-info screen and capture the launcher icon under the device's mask:

```powershell
adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.hopa.android
adb shell screencap -p /sdcard/hopa-icon.png
adb pull /sdcard/hopa-icon.png docs/media/android-plush-icon-2026-11-18.png
```

Check in the screenshot: the face and raised hand are inside the mask; the badge is cream with no transparent gaps.

- [ ] **Step 2: Check reduced motion and small sizes on Android**

```powershell
adb shell settings put global animator_duration_scale 0
adb shell am force-stop com.hopa.android
adb shell am start -n com.hopa.android/com.hopa.app.MainActivity
adb shell screencap -p /sdcard/hopa-still.png
adb pull /sdcard/hopa-still.png docs/media/android-plush-still-2026-11-18.png
adb shell settings put global animator_duration_scale 1
```

Expected: the hero is still while the scale is 0; motion returns at 1. In the home screenshot, the 26 dp answer avatar is legible.

- [ ] **Step 3: Capture Windows**

Run: `apps\windows\Hopa.Windows\bin\Debug\net8.0-windows\Hopa.Windows.exe --shot-frame docs/media/windows-plush-empty-2026-11-18.png`
Expected: a screenshot of the empty state with the plush mark.

Check the taskbar and Alt-Tab icons show the plush squircle, not the default .NET icon. Set Windows display scaling to 150% and confirm the empty-state badge has clean corners; set it back.

- [ ] **Step 4: Write the evidence**

Create `docs/project/evidence/plush-mark-2026-11-18.md` with:

- What changed, for which clients, and the source photo path.
- The generator command and the four pytest results.
- The Android build and smoke commands and their screenshots.
- The Windows build and test commands and the screenshot.
- An explicit note: Android and Windows now diverge from Harmony's phone mark; the repo README still describes the phone (out of scope).
- The reduced-motion and 150% DPI checks.
- Any tuning left (timings, blink at 20 dp).

- [ ] **Step 5: Update the Android guide**

In `docs/guides/android/release.md`, replace the launcher-icon section with: source `tools/assets/hopa-plush-2026.jpg`, the adaptive background `#F7F1E6`, the 47% composition and 33 dp safe radius, the regenerated files (legacy, foreground, avatar, blink), and `python tools/scripts/make-icon.py`. State that the monochrome layer is hand-drawn, not generated.

- [ ] **Step 6: Run the repo checks**

```powershell
python tools/checks/check-structure.py --strict
python tools/checks/check-android-structure.py
python tools/checks/check-tree.py
python tools/checks/check-links.py
python -m pytest tools/scripts -q
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add docs/guides/android/release.md docs/project/evidence/plush-mark-2026-11-18.md docs/media/android-plush-home-2026-11-18.png docs/media/android-plush-icon-2026-11-18.png docs/media/android-plush-still-2026-11-18.png docs/media/windows-plush-empty-2026-11-18.png
git commit -m "docs(evidence): verify the plush mark on the phone and the desktop"
```
