# CONTINUE — HOPA cloud relay

Updated: 2026-11-11 (evening)
Objective: one HOPA cloud relay for the phone and the laptop, with no USB.
**The phone-only setup is done and verified cable-free.** The laptop remains.

---

## 1. Phone status (verified)

The phone works through the cloud relay with the USB cable **disconnected**:

| Check | Result |
|---|---|
| Relay `default` session | `host=true, phone=true` |
| `/observe` (cloud) | **10/10**, 36 nodes, 1280x2832, ~3.5–10 s each |
| `/observe` after unplugging USB | **3/3** |
| `/screenshot` (cloud) | valid JPEG, ~196 KB |
| `/foreground` (cloud) | `com.hopa.agent` |
| `/tap` (cloud) | `{"ok":true}` |
| App stability | no crash, process stays alive |

Live relay: `https://hopa-relay.onrender.com`

```json
{"tunnel":{"links":[
  {"session":"default","host":true,"phone":true},
  {"session":"laptop","host":true,"phone":false}
]}}
```

The phone USB target shows `Offline` in `hdc list targets`; every check above
went through the relay and the tunnel, not USB.

---

## 2. Root causes found and fixed

### 2.1 The phone app was crashing on the WebSocket error handler

`TunnelClient.ets:265` did:

```ts
this.fail(err.message.length > 0 ? err.message : 'websocket error');
```

HarmonyOS can deliver a WebSocket `error` callback whose `BusinessError` has no
`message`. Reading `.length` then throws inside the native callback, which
crashes the whole app:

```text
TypeError: Cannot read property length of undefined
  at anonymous entry (phone/src/main/ets/services/TunnelClient.ets:265:29)
```

The system recorded a `$JS_ERROR` jscrash and killed the process
(`onAbilityDied`, `terminateReason: 2`). That is why the phone tunnel kept
disappearing and why the app sometimes died one second after launch.

Fix: a guarded helper in both `TunnelClient.ets` and `LaptopTunnel.ets`:

```ts
private static errorText(error: BusinessError | undefined, fallback: string): string
```

Every `open` / `message` / `close` / `error` / `connect().catch` callback now
goes through it. The app no longer crashes; it logs and reconnects instead.

### 2.2 A tunneled hdc target dies after a handful of commands

Over the tunnel, the hdc target session stops answering after about five
commands. `tconn` still reports "already connected" and the next command can
return an empty result instead of an error. The old `dump_layout` used three
commands (`uitest dumpLayout`, `hdc file recv`, `rm`) and silently accepted
empty/spliced pulls, so `/observe` failed intermittently.

Fixes in `services/pc-agent`:

- `Device.dump_layout` now runs **dump + cat + cleanup in one hdc shell
  command**, with `__HOPA_BEGIN__` / `__HOPA_END__` markers, and verifies the
  JSON.
- On failure it calls `Hdc.recover()` (restart the local hdc server, `tconn`)
  and retries, up to 3 attempts.
- `Device.screenshot` verifies the JPEG magic/size and retries once with the
  same recovery.
- `Hdc.recover()` is new; USB targets are left alone.

`/observe` is now one device command per call, which is what made 10/10 pass.

---

## 3. Live architecture (one relay, two sessions)

```text
                 ONE Render relay: hopa-relay.onrender.com
                 /tunnel, /health, /pair, ...
                      │                       │
          session "default"           session "laptop"
                      │                       │
      PC hdc-tunnel :5556             PC hdc-tunnel :5557
                      │                       │
                phone hdcd :5555        laptop hdcd :5555
```

- **One** relay service, **one** `/tunnel` endpoint.
- **Two** tunnel sessions: `default` = phone, `laptop` = laptop.
- **Two** PC `hdc-tunnel` listeners: `5556` and `5557`.
- **One** PC bridge pool on `8765`; it routes by `X-Hopa-Role: phone|2in1`.
- **One** cloud link and **one** shared conversation store.
- The laptop's local `8767` bridge is a fallback, not a second relay.
- Both app tunnels dial **out**, so neither device needs an inbound port.

---

## 4. Repo / branch state

```text
feat/laptop-tunnel
d224a74 docs: record the draft PR and stop point in CONTINUE.md
6d0e22b feat: add the laptop tunnel client and cloud runner
+ (this session) phone crash guard + one-command layout read + hdc recovery
draft PR #26 — https://github.com/agents-demo/hopa/pull/26
```

Local `main` still has the unpushed signing commit
(`build: restore local signing material for the Mate 80`).

> **Building the apps on this branch:** `apps/harmony/build-profile.json5`
> points at `C:\Users\m00645993\...`, which does not exist on this machine.
> Temporarily apply the local `main` config, build, then restore it:
>
> ```powershell
> git show main:apps/harmony/build-profile.json5 | Set-Content -Encoding utf8 apps\harmony\build-profile.json5
> .\tools\scripts\build.ps1
> git checkout -- apps/harmony\build-profile.json5
> ```
>
> The phone HAP installed during this session was built this way and contains
> the crash guard.

---

## 5. Reproduce the phone-only cable-free test

### 5.1 Prerequisites

- Phone Wi-Fi is **connected with an IP**.
  Check inside the phone shell:
  ```powershell
  hdc -t <serial> shell "ifconfig wlan0"
  hdc -t <serial> shell "ping -c 1 hopa-relay.onrender.com"
  ```
  Without an IP the tunnel cannot connect (DNS fails). `svc wifi enable` alone
  does not associate; connect from Settings.
- PC pool and both host tunnels:
  ```powershell
  .\tools\scripts\run-agent.ps1 -Status
  ```
  Expect `bridge: http://127.0.0.1:8765 (pool: phone=127.0.0.1:5556, ...)`.

### 5.2 Start the app tunnel (only needed after a cold start or stale settings)

```powershell
$cfg = @{}
Get-Content .env | ForEach-Object {
  $l = $_.Trim()
  if ($l -and -not $l.StartsWith('#') -and $l.Contains('=')) {
    $i = $l.IndexOf('='); $cfg[$l.Substring(0,$i).Trim()] = $l.Substring($i+1).Trim().Trim('"').Trim("'")
  }
}
$tok = $cfg['HOPA_BRIDGE_TOKEN']
hdc shell "aa start -a EntryAbility -b com.hopa.agent --ps hopa.bridge_url https://hopa-relay.onrender.com --ps hopa.bridge_token $tok --ps hopa.tunnel 1"
```

The launch parameters are remembered, so this is usually a one-time step.

### 5.3 Verify and test through the cloud

```powershell
# per-session status
Invoke-RestMethod https://hopa-relay.onrender.com/health |
  ConvertTo-Json -Depth 6
# expect default: host=true, phone=true

# observe through the cloud
Invoke-RestMethod -Method Post `
  -Uri https://hopa-relay.onrender.com/observe `
  -Headers @{Authorization="Bearer $tok"; 'X-Hopa-Role'='phone'} `
  -ContentType 'application/json' -Body '{}'
# expect nodes=36, 1280x2832

# screenshot (returns JSON with a base64 JPEG)
Invoke-WebRequest -Method Post `
  -Uri https://hopa-relay.onrender.com/screenshot `
  -Headers @{Authorization="Bearer $tok"; 'X-Hopa-Role'='phone'} `
  -ContentType 'application/json' -Body '{}' -OutFile shot.json
```

To prove cable-free: unplug the USB cable, then run the same calls. `hdc list
targets` will show the phone USB as `Offline`; the cloud calls still work.

### 5.4 Model configuration

The model also comes from `.env` (`HOPA_MODEL_PROVIDER`, `HOPA_MODEL_BASE_URL`,
`HOPA_MODEL_NAME`, `HOPA_MODEL_API_KEY`). A launch can set and persist it:

```powershell
hdc shell "aa start -a EntryAbility -b com.hopa.agent --ps hopa.provider $($cfg['HOPA_MODEL_PROVIDER']) --ps hopa.base_url $($cfg['HOPA_MODEL_BASE_URL']) --ps hopa.model $($cfg['HOPA_MODEL_NAME']) --ps hopa.api_key $($cfg['HOPA_MODEL_API_KEY']) --ps hopa.bridge_url $relay --ps hopa.bridge_token $($cfg['HOPA_BRIDGE_TOKEN']) --ps hopa.tunnel 1"
```

`applyLaunchConfig` saves the key to secure storage (`KeyStore`), so a later
cold start without parameters keeps the model. AppBoot now prefers the stored
provider/endpoint/model instead of overwriting them with the hardcoded
DeepSeek defaults.

Current phone settings (Settings → MODEL):

```text
Provider:    deepseek
Endpoint:    https://api.deepseek.com
Model name:  deepseek-flash
API key:     loaded (stored securely)
```

`Capabilities` shows `deepseek-flash — PC bridge` under "Ready on this phone".

---

## 6. Laptop (remaining)

The laptop tunnel code exists and is committed, but it has **not** been
verified end to end, and the laptop is currently in TCP mode with its USB
target offline.

Resume:

1. Rebuild + install the laptop HAP (use the build-profile workaround above).
   The crash guard is now in `LaptopTunnel.ets` too.
2. Open HOPA on the laptop; check `/health`:
   - `laptop.phone=true` → app tunnel attached.
3. Try hdc over the tunnel:
   ```powershell
   hdc tconn 127.0.0.1:5557
   hdc -t 127.0.0.1:5557 shell "echo laptop-ok"
   ```
4. If it still fails, test direct PC → laptop TCP `11.248.91.112:5555`.
   If that works, point the pool's `2in1` target at the address and retire the
   laptop tunnel.
5. Restore laptop USB with `tmode usb`/reboot only if a rebuild or logs are
   needed.
6. Verify, then merge PR #26 and update this file.

Do **not** uninstall the laptop app; its data and signing identity are stable.

---

## 7. Known limitations / do not do

- **Phone Wi-Fi must have an IP.** When `wlan0` has no address, the tunnel
  cannot resolve the relay. `svc wifi enable` does not associate a network.
- HOPA must stay running. A backgrounded app can be suspended by HarmonyOS;
  the continuous task helps but is not a guarantee.
- A tunneled hdc target still dies after several commands. The bridge hides
  this for `/observe` (one command + recover/retry); screenshots still use a
  few commands and may retry.
- The relay keeps two sessions; the laptop uses `laptop`, the phone `default`.
- Both devices share one token; the pool routes by `X-Hopa-Role`.
- Do not commit `apps/harmony/build-profile.json5` with signing material.
- Do not uninstall the laptop app.
- The plan still has two platform-blocked boxes:
  1. Pushed static arm64 forwarder — SELinux blocks execution from
     `/data/local/tmp`.
  2. 10-minute screen-off hold — HarmonyOS suspends the app's JS/TCP handlers.
