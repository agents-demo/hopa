# Device bundle names

Bundle names are the first thing an agent gets wrong. Every name below was
checked on the Pura 90 emulator (HarmonyOS 6.1.1, API 24) on 2026-11-06 with:

```bash
pc-agent apps
hdc shell bm dump -n <bundle>
hdc shell aa start -a <ability> -b <bundle>
hdc shell uitest dumpLayout -p /data/local/tmp/layout.json
```

A name is "verified" only when the bundle exists **and** the launched screen
matches the app. "Not on this image" is not a failure of the name; it means the
name cannot be checked here.

## Knowledge apps (`services/brain/knowledge/apps`)

| App | Bundle | Status | How it was checked |
|---|---|---|---|
| Settings | `com.huawei.hmos.settings` | verified | launched, WLAN screen read; ability `com.huawei.hmos.settings.MainAbility` |
| Browser | `com.huawei.hmos.browser` | verified | launched, homepage search field read; ability `MainAbility` |
| Calendar | `com.huawei.hmos.calendar` | verified | launched, `phone_add_agenda` present; ability `MainAbility` |
| Files | `com.huawei.hmos.files` | verified | launched, Browse screen read; ability `EntryAbility` |
| Gallery | `com.huawei.hmos.photos` | verified | launched, "Gallery" title read; ability `com.huawei.hmos.photos.MainAbility` |
| Contacts / Phone | `com.ohos.contacts` | verified | launched, Phone/Contacts/Favorites tabs read; ability `com.ohos.contacts.EntryAbility` |
| AppGallery | `com.huawei.hmsapp.appgallery` | verified | present in `pc-agent apps`, bundle dump ok; ability `MainAbility` |
| Camera | `com.huawei.hmos.camera` | not on this image | absent from `pc-agent apps` |
| Clock | `com.huawei.hmos.clock` | not on this image | absent from `pc-agent apps` |
| Music | `com.huawei.hmos.music` | not on this image | absent; only `com.huawei.hms.musicservice` exists |
| Notepad / Notes | `com.huawei.hmos.notepad` | not on this image | absent from `pc-agent apps` |
| Petal Maps | `com.huawei.hmos.petalmaps` | not on this image | absent from `pc-agent apps` |

Three names in the first draft were wrong and are now corrected:
`com.huawei.hmos.contacts` -> `com.ohos.contacts`,
`com.huawei.hmos.gallery` -> `com.huawei.hmos.photos`,
`com.huawei.hmos.appgallery` -> `com.huawei.hmsapp.appgallery`.

## Catalogued but unconfirmed (15 apps)

These have an `APP.md` with `bundle: UNCONFIRMED`, so they match by name/alias
but never launch by a guessed package. Replace `UNCONFIRMED` only after
`bm dump -n` or AppGallery confirms the HarmonyOS bundle.

| App | Android package | HarmonyOS bundle |
|---|---|---|
| Baijiahao | `com.baidu.baijia` | to confirm |
| Bilibili | `tv.danmaku.bili` | to confirm |
| BOSS Zhipin | `com.hpbr.bosszhipin` | to confirm |
| Dedao | `com.luojilab.player` | to confirm |
| Douyin | `com.ss.android.ugc.aweme` | to confirm |
| Feishu | `com.ss.android.lark` | to confirm |
| Jike | `com.ruguoapp.jike` | to confirm |
| Kuaishou | `com.smile.gifmaker` | to confirm |
| QQ Mail | `com.tencent.androidqqmail` | to confirm |
| Toutiao | `com.ss.android.article.news` | to confirm |
| WeChat | `com.tencent.mm` | to confirm |
| Weibo | `com.sina.weibo` | to confirm |
| Xianyu | `com.taobao.idlefish` | to confirm |
| Xiaohongshu | `com.xingin.xhs` | to confirm |
| Zhihu | `com.zhihu.android` | to confirm |

## Bench tasks (`harness/bench/tasks`)

| Task | Bundle | Status |
|---|---|---|
| `settings-wlan` | `com.huawei.hmos.settings` | verified, passes |
| `calendar-new-event` | `com.huawei.hmos.calendar` | verified, passes |
| `browser-search-harmonyos` | `com.huawei.hmos.browser` | verified, passes |
| `contacts-find` | `com.ohos.contacts` | verified bundle, selector still fails |
| `files-locate` | `com.huawei.hmos.files` | verified bundle, search field not reachable |
| `settings-wifi-toggle` | `com.huawei.hmos.settings` | verified, passes |
| `settings-brightness` | `com.huawei.hmos.settings` | verified, passes |
| `clock-*` | `com.huawei.hmos.clock` | not on this image |
| `notes-*` | `com.huawei.hmos.notepad` | not on this image |
| `messages-*` | `com.huawei.hmos.mms` | not on this image |
| `music-*` | `com.huawei.hmos.music` | not on this image |

## Check a device

The catalogue and the installed bundles drift apart quickly. Run:

```powershell
py tools/scripts/verify-bundles.py --hdc "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" --device 127.0.0.1:5555
```

It prints all 27 apps, whether each bundle is installed, and whether the file
has `bundle_verified`. Use `--input bm-dump.txt` for a saved `bm dump -a`
output, and `--check` to exit 1 when an app marked verified is missing. The tool
does not edit `APP.md`; add `bundle_verified` only after a launch smoke test.

## How to re-check on another device

```bash
pc-agent apps
for b in com.huawei.hmos.settings com.huawei.hmos.calendar; do
  hdc shell bm dump -n "$b" | head
done
```

Update this table and the task files together. Never change a bundle in one
place only.

## Limits

- A bundle can differ between regions and between HarmonyOS and Android builds.
- A bundle that exists is not proof that a specific screen or element exists;
  selectors need their own check.
- None of this was checked on a physical phone yet.
