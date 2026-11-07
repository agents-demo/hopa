# Web capability

Status: **stub.** The entry app does not yet host a `Web` component for the
capability, and no site has been tested.

## Ownership

- `entry` owns the ArkUI `Web` component and its lifecycle.
- `entry` passes the `WebviewController` to `BrowserCapability`.
- `BrowserCapability` must not create a second hidden browser for normal browsing.

## Actions

| Action | Implementation |
|---|---|
| `web.navigate` | `controller.loadUrl(url)` after `UrlPolicy` |
| `web.read` | `runJavaScript` returns visible text |
| `web.click` | resolve a ref to a DOM selector, then click |
| `web.type` | focus a field, set the value, dispatch input |

## Security

- HTTPS only; host allow-list; no userinfo.
- Network is off unless the user enables it for the task.
- Cookies and storage are isolated per task profile.
- Signed-in state is detected, never assumed.
- Downloads and file pickers require approval.
- Deep links pass the same `UrlPolicy` as the executor.

## Status and gaps

- No controller wiring.
- No DOM ref map.
- No 5-site test.
- No cookie isolation or signed-in detection.
- No download/file-picker approval.
- The ArkWeb engine differs between API 24 (Chromium 132) and API 26 (144);
  re-test after the upgrade.

## Tests to add

1. Load a page and read its title.
2. Search and open the first result.
3. Fill a form without submitting.
4. Detect a signed-in page.
5. Reject an unapproved host.
