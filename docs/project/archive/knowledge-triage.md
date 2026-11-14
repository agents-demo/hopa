# App catalogue triage

The catalogue includes 23 third-party Android app files. Each is classified as:

- **replaced** — HOPA has its own HarmonyOS system app.
- **app?** — a HarmonyOS build may exist; confirm the bundle before adding an `APP.md`.
- **web-only** — no HarmonyOS app expected; use a `SITE.md`.

`app?` is deliberately unresolved. Do not add an `APP.md` until the bundle is
confirmed with `hdc shell bm dump -a` or AppGallery.

| # | Catalogue id | Android package | Status | Web site | Action |
|---|---|---|---|---|---|
| 1 | android-settings | `com.android.settings` | replaced | — | HOPA `settings` |
| 2 | baijiahao | `com.baidu.baijia` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 3 | bilibili | `tv.danmaku.bili` | app? | bilibili.com | confirm bundle; site included; APP.md with UNCONFIRMED |
| 4 | boss-zhipin | `com.hpbr.bosszhipin` | app? | zhipin.com | confirm bundle; site included; APP.md with UNCONFIRMED |
| 5 | chrome | `com.android.chrome` | web-only | — | use the built-in browser (no site file) |
| 6 | dedao | `com.luojilab.player` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 7 | douyin | `com.ss.android.ugc.aweme` | app? | douyin.com | confirm bundle; site included; APP.md with UNCONFIRMED |
| 8 | feishu | `com.ss.android.lark` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 9 | gmail | `com.google.android.gm` | web-only | mail.google.com | site included |
| 10 | jike | `com.ruguoapp.jike` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 11 | kuaishou | `com.smile.gifmaker` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 12 | linkedin | `com.linkedin.android` | web-only | linkedin.com | site included |
| 13 | qqmail | `com.tencent.androidqqmail` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 14 | telegram | `org.telegram.messenger` | web-only | telegram.org | site included |
| 15 | toutiao | `com.ss.android.article.news` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 16 | uber | `com.ubercab` | web-only | uber.com | site included |
| 17 | uber-eats | `com.ubercab.eats` | web-only | ubereats.com | site included |
| 18 | wechat | `com.tencent.mm` | app? | weixin.sogou.com | confirm bundle; search site included; APP.md with UNCONFIRMED |
| 19 | weibo | `com.sina.weibo` | app? | weibo.com | confirm bundle; site included; APP.md with UNCONFIRMED |
| 20 | whatsapp | `com.whatsapp` | web-only | whatsapp.com | site included |
| 21 | xianyu | `com.taobao.idlefish` | app? | — | confirm bundle; APP.md with UNCONFIRMED |
| 22 | xiaohongshu | `com.xingin.xhs` | app? | xiaohongshu.com | confirm bundle; site included; APP.md with UNCONFIRMED |
| 23 | zhihu | `com.zhihu.android` | app? | zhihu.com | confirm bundle; site included; APP.md with UNCONFIRMED |

## Summary

| Status | Count |
|---|---|
| replaced | 1 |
| app? | 15 (all catalogued with `bundle: UNCONFIRMED`) |
| web-only | 7 |

## Sites

21 sites are included as `services/brain/knowledge/sites/<domain>/SITE.md`. Each
has the domain, aliases, linked apps and `validated: pending`.

Chrome has no site file: an "open Chrome" request uses the built-in browser
instead.

## Next

1. For each `app?`, search AppGallery and record the HarmonyOS bundle, then
   replace `UNCONFIRMED` and set `validated` to the test date.
2. Smoke-test each site and change `validated: pending` to a date.
3. Add a per-app screen note after the first real run.
