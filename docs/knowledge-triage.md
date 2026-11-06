# Mika app triage

Mika has 23 Android app files. HOPA cannot copy them. Each is classified as:

- **replaced** — HOPA has its own HarmonyOS system app.
- **app?** — a HarmonyOS build may exist; confirm the bundle before adding an `APP.md`.
- **web-only** — no HarmonyOS app expected; use a `SITE.md`.

`app?` is deliberately unresolved. Do not add an `APP.md` until the bundle is
confirmed with `hdc shell bm dump -a` or AppGallery.

| # | Mika id | Android package | Status | Web site | Action |
|---|---|---|---|---|---|
| 1 | android-settings | `com.android.settings` | replaced | — | HOPA `settings` |
| 2 | baijiahao | `com.baidu.baijia` | app? | — | confirm bundle |
| 3 | bilibili | `tv.danmaku.bili` | app? | bilibili.com | confirm bundle; site ported |
| 4 | boss-zhipin | `com.hpbr.bosszhipin` | app? | zhipin.com | confirm bundle; site ported |
| 5 | chrome | `com.android.chrome` | web-only | — | use the built-in browser (no site file) |
| 6 | dedao | `com.luojilab.player` | app? | — | confirm bundle |
| 7 | douyin | `com.ss.android.ugc.aweme` | app? | douyin.com | confirm bundle; site ported |
| 8 | feishu | `com.ss.android.lark` | app? | — | confirm bundle |
| 9 | gmail | `com.google.android.gm` | web-only | mail.google.com | site ported |
| 10 | jike | `com.ruguoapp.jike` | app? | — | confirm bundle |
| 11 | kuaishou | `com.smile.gifmaker` | app? | — | confirm bundle |
| 12 | linkedin | `com.linkedin.android` | web-only | linkedin.com | site ported |
| 13 | qqmail | `com.tencent.androidqqmail` | app? | — | confirm bundle |
| 14 | telegram | `org.telegram.messenger` | web-only | telegram.org | site ported |
| 15 | toutiao | `com.ss.android.article.news` | app? | — | confirm bundle |
| 16 | uber | `com.ubercab` | web-only | uber.com | site ported |
| 17 | uber-eats | `com.ubercab.eats` | web-only | ubereats.com | site ported |
| 18 | wechat | `com.tencent.mm` | app? | weixin.sogou.com | confirm bundle; search site ported |
| 19 | weibo | `com.sina.weibo` | app? | weibo.com | confirm bundle; site ported |
| 20 | whatsapp | `com.whatsapp` | web-only | whatsapp.com | site ported |
| 21 | xianyu | `com.taobao.idlefish` | app? | — | confirm bundle |
| 22 | xiaohongshu | `com.xingin.xhs` | app? | xiaohongshu.com | confirm bundle; site ported |
| 23 | zhihu | `com.zhihu.android` | app? | zhihu.com | confirm bundle; site ported |

## Summary

| Status | Count |
|---|---|
| replaced | 1 |
| app? | 15 |
| web-only | 7 |

## Sites

21 sites are ported as `brain/knowledge/sites/<domain>/SITE.md`. Each has the
domain, aliases, linked apps and `validated: pending`.

Chrome has no site file: a "open Chrome" request uses the built-in browser
(Web tab) instead.

## Next

1. For each `app?`, search AppGallery and record the HarmonyOS bundle.
2. Add `APP.md` only for confirmed bundles.
3. Smoke-test each site and change `validated: pending` to a date.
