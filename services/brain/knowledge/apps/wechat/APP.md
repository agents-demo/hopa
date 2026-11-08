---
name: wechat
display: WeChat
bundle: UNCONFIRMED
aliases: [WeChat, 微信, weixin, wechat]
pace: careful
validated: pending
platform: harmonyos
---
# WeChat

Android package: `com.tencent.mm`. A HarmonyOS build exists, but its bundle
has not been confirmed on a device yet, so HOPA does not launch it by bundle.

- Chats, contacts, search, Moments, Pay, mini programs.
- Sending a message is public and effectively irreversible: show recipient and
  text, then ask.
- WeChat Pay is a payment: always ask, show amount and merchant if visible.
- Never read a verification code or password; hand login to the user.
