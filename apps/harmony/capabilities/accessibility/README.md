# a11y capability — restricted / ACL

This module is a **skeleton**. Do not enable it in production until all of the
following are true:

1. Huawei has approved the **ACL request** for the accessibility restricted
   permission (exact permission string and profile steps must be confirmed in the
   official permission list for API 26).
2. The `AccessibilityExtensionAbility` is declared in `src/main/module.json5`
   under `extensionAbilities` with `"type": "accessibility"` and the extension's
   `srcEntry`.
3. The user has enabled the HOPA accessibility service in
   **Settings → Accessibility**.

Until then, `A11yCapability.isAvailable()` must stay `false`, and the entry app
must show the capability as unavailable. The executor still records any attempted
`a11y.*` action as `unsupported`/`failed`, never silently.

The extension file lives at
`src/main/ets/extension/AccessibilityExtension.ets`. It is intentionally not
declared in `module.json5` yet so an unapproved build cannot register a restricted
service. Its import path/signature is validated against the installed API 26 SDK.
