# CONTINUE — HOPA cloud relay for phone + laptop

Updated: 2026-11-11 (local session)
Objective: both the phone and the laptop use the **single** HOPA cloud relay,
with no USB connection.

> **UPDATE — after PR #25 deploy (2026-11-11 evening).**
>
> PR #25 is merged and deployed; `/health.tunnel.links` is live. The relay
> restart dropped both app tunnels. The current status is:
>
> ```json
> {"tunnel":{"sessions":2,"host":true,"phone":false,"ready":false,
>  "links":[{"session":"default","host":true,"phone":false},
>           {"session":"laptop","host":true,"phone":false}]}}
> ```
>
> Both PC host tunnels reconnected; **both app tunnels are absent**. The phone
> foreground command was interrupted, so the phone app tunnel may still be
> down. The laptop app is open, no debugging prompt, but its tunnel is absent.
> The direct PC→laptop `11.248.91.112:5555` test was interrupted.
>
> **Immediate next steps:**
>
> 1. Foreground the phone app; verify `default.phone=true` and `/observe`
>    role `phone`.
> 2. Foreground/relaunch the laptop app; verify `laptop.phone=true`.
> 3. If `laptop.phone=true` but hdc fails, test the PC→laptop direct TCP
>    (`11.248.91.112:5555`). If direct works, point the pool's 2in1 entry at
>    that address and retire the laptop tunnel; if not, investigate the
>    laptop app's TCP/SELinux/auth to 5555.
> 4. If `laptop.phone=false`, fix `LaptopTunnel` start/wake (the app's
>    `LaptopAbility.onForeground` and `LaptopIndex.startIfWanted` paths).
> 5. The laptop USB is offline; restore it with `tmode usb`/reboot if a
>    rebuild or log inspection is needed.
> 6. The WIP is committed on `feat/laptop-tunnel` (draft PR); see §3/§5.

---

## 1. Current state at a glance

| Piece | State |
|---|---|
| Render relay | Live, one service: `https://hopa-relay.onrender.com` |
| Relay role forwarding (`X-Hopa-Role`) | Deployed |
| Relay per-session `links` status | **Deployed (PR #25)** |
| PC bridge pool | Live on `127.0.0.1:8765` |
| Cloud link | Live |
| Phone hdc tunnel | Live on `127.0.0.1:5556` |
| Laptop hdc tunnel (host) | Live on `127.0.0.1:5557` |
| Phone path | **Working through the pool** |
| Laptop path | **Blocked** (see §4) |
| Laptop local `8767` bridge | Stopped |
| Phone USB | Still connected, but the phone tunnel works |
| Laptop USB | **Offline** after `tmode port 5555` |

Last relay `/health` (before the PR #25 restart):

```json
{"tunnel":{"sessions":2,"host":true,"phone":true,"ready":true}}
```

After the PR #25 deploy, both app tunnels were absent:

```json
{"tunnel":{"sessions":2,"host":true,"phone":false,"ready":false,
 "links":[{"session":"default","host":true,"phone":false},
          {"session":"laptop","host":true,"phone":false}]}}
```

Last successful phone test through the pool:

```text
POST /observe  X-Hopa-Role: phone  -> 34 nodes, 1280x2832
hdc -t 127.0.0.1:5556 shell         -> works
```

Last laptop test:

```text
hdc tconn 127.0.0.1:5557            -> "Target is connected"
hdc -t 127.0.0.1:5557 shell         -> blank / timeout
POST /observe X-Hopa-Role: 2in1     -> 500
  {"error":"DeviceError: layout dump produced no file"}
```

---

## 2. Architecture (one relay, two sessions)

```
                 ONE Render relay: hopa-relay.onrender.com
                 /tunnel, /health, /pair, ...
                      │                       │
          session "default"           session "laptop"
                      │                       │
      PC hdc-tunnel :5556             PC hdc-tunnel :5557
                      │                       │
                phone hdcd :5555        laptop hdcd :5555
```

- **One** relay service.
- **Two** tunnel sessions:
  - `default` = phone
  - `laptop` = laptop
- **Two** PC `hdc-tunnel` listeners: `5556` and `5557`.
- **One** PC bridge pool on `8765`; it routes HTTP requests by
  `X-Hopa-Role: phone` or `X-Hopa-Role: 2in1`.
- **One** cloud link and **one** shared `/chats` store.
- The laptop’s local `8767` bridge is a fallback, not a second relay.

The README now has the same flow as a Mermaid diagram under
**“One relay, two devices”** — but that README edit is currently in the
`laptop tunnel WIP` stash (see §3).

---

## 3. Repository / branch / stash state

Current branch after this commit:

```text
feat/laptop-tunnel
feat: add the laptop tunnel client and cloud runner (WIP)
draft PR (to be created)
```

PR #25 (`feat/tunnel-links`) is **merged and deployed**.

The WIP is no longer in a stash; it is committed on `feat/laptop-tunnel`.
It contains:

- `README.md` — “One relay, two devices” + Mermaid flow
- `apps/harmony/laptop/src/main/ets/services/LaptopTunnel.ets`
- `apps/harmony/laptop/src/main/ets/entryability/LaptopAbility.ets`
- `apps/harmony/laptop/src/main/ets/pages/LaptopIndex.ets`
- `tools/scripts/run-agent.ps1` — pool target `5557`, laptop tunnel start/stop/status
- `tools/scripts/run-laptop.ps1` — cloud mode + `hopa.laptop_tunnel`
- `CONTINUE.md` — this file

> **Do not restart `run-agent.ps1` before restoring the stash.** The live PC
> processes were started from the WIP. The files currently on disk are the
> `origin/main` versions and do not have the laptop-tunnel pool target.

Local `main` has the unpushed signing commit:

```text
929981f build: restore local signing material for the Mate 80
```

`apps/harmony/build-profile.json5` on local `main` now uses the corrected
keystore passwords (`…B05AA10EA…` / `…FC8968F2…`) for the regenerated Huawei
profile. The branch `feat/tunnel-links` is from `origin/main` and still has the
upstream signing paths; use local `main` (or temporarily apply its
`build-profile.json5`) if you need to build the apps.

The laptop HAP **with `LaptopTunnel` was built and installed successfully**
(`install bundle successfully`). Its source is in the WIP stash.

---

## 4. Current blocker

The laptop app is open, no debugging prompt appeared, and the laptop hdcd is
listening:

```text
laptop: 0.0.0.0:5555 (15B3), uid 2000
```

But the hdc bytes over the laptop tunnel do not reach a usable session. The
aggregate relay status cannot tell whether:

1. The laptop app’s `LaptopTunnel` is **not attached** to session `laptop` — only
   the PC host tunnel is attached, so `hdc` connects to a dead stream; or
2. The app tunnel is attached, but the app is denied the local TCP connection
   to `127.0.0.1:5555` (SELinux/auth/pairing), so every OPEN stream closes.

PR #25’s per-session `links` will distinguish these:

- `laptop: host=true, phone=true` → app tunnel is attached; investigate the
  app’s TCP access to 5555.
- `laptop: host=true, phone=false` → the app tunnel did not start; fix the
  app/settings start path.

The laptop USB target is now **offline** because `hdc tmode port 5555` put the
device in TCP mode. That means no USB logs/screenshots/install until USB mode
is restored.

---

## 5. Next steps (in order)

### 5.1 Finish PR #25 and deploy

1. Let CI finish for PR #25.
2. Merge it.
3. Trigger a Render deploy of `main` if auto-deploy does not fire.
4. Confirm the deployed relay includes `tunnel.links`.

### 5.2 Read the per-session status

```powershell
Invoke-RestMethod https://hopa-relay.onrender.com/health |
  ConvertTo-Json -Depth 5
```

Look at `tunnel.links`:

```json
{"tunnel":{"links":[
  {"session":"default","host":true,"phone":true},
  {"session":"laptop","host":true,"phone":true}
]}}
```

### 5.3 Restore the WIP

After PR #25 is merged (or immediately, if you prefer):

```powershell
git switch main
git pull --rebase origin main
git stash pop
```

Then verify the WIP is back:

```powershell
Select-String tools\scripts\run-agent.ps1 -Pattern 'laptopTunnel|5557'
Test-Path apps\harmony\laptop\src\main\ets\services\LaptopTunnel.ets
```

### 5.4 Diagnose based on `tunnel.links`

**If `laptop.phone = true`:**

- The app tunnel is attached.
- Inspect the laptop app’s TCP to `127.0.0.1:5555`:
  - SELinux may deny the app uid.
  - The tmode hdcd may require a pairing/authorization.
- The phone app’s tunnel uses the same pattern and works, so compare the
  laptop app’s `LaptopTunnel` logs/behavior with the phone.
- If TCP is denied, the laptop needs a different local transport or an
  authorization/pairing step.

**If `laptop.phone = false`:**

- The app tunnel did not start.
- Check `hopa_settings` on the laptop for:
  - `bridge_url = https://hopa-relay.onrender.com`
  - `bridge_token` = phone token
  - `tunnel = true`
- Relaunch the laptop app with the WIP `run-laptop.ps1` while USB is available,
  or open Settings → Bridge and re-apply/connect.
- The `LaptopIndex` start path is:
  - `LaptopAbility.onCreate` reads `hopa.laptop_tunnel`
  - `LaptopIndex.applyInjected` saves `stored.tunnel` and calls
    `LaptopTunnel.get().start()`
  - `LaptopIndex.aboutToAppear` calls `startIfWanted(context)`

### 5.5 Restore laptop USB if inspection or rebuild is needed

The laptop is in TCP mode (`tmode port 5555`) and its USB hdc target is
offline. To get USB back:

- If a working hdc path exists:
  ```powershell
  hdc -t 127.0.0.1:5557 tmode usb
  ```
- Otherwise, reconnect the laptop USB and/or reboot the laptop, or use the
  laptop’s Developer options / wireless-debugging settings to switch back.
- Once USB is back:
  ```powershell
  hdc -t 3QC0225821000268 list targets
  ```

### 5.6 Commit the WIP once the laptop path works

The WIP should become one branch/PR after it is verified:

- relay/role status work is already merged/deployed
- `run-agent.ps1` pool + laptop tunnel
- `run-laptop.ps1` cloud mode + `hopa.laptop_tunnel`
- `LaptopTunnel.ets` + `LaptopAbility` / `LaptopIndex`
- README Mermaid flow

Do not commit `apps/harmony/build-profile.json5` with signing secrets; keep
the local signing commit local/unpushed.

---

## 6. Important commands

```powershell
# PC side
.\tools\scripts\run-agent.ps1 -Status
.\tools\scripts\run-agent.ps1 -Restart

# Laptop app (cloud mode; USB required to launch with params)
.\tools\scripts\run-laptop.ps1
.\tools\scripts\run-laptop.ps1 -Status
.\tools\scripts\run-laptop.ps1 -Stop       # stops the local 8767 bridge only

# Relay
Invoke-RestMethod https://hopa-relay.onrender.com/health

# Pool role checks
curl.exe -s -X POST http://127.0.0.1:8765/observe `
  -H "Authorization: Bearer $env:HOPA_BRIDGE_TOKEN" `
  -H "X-Hopa-Role: phone" -H "Content-Type: application/json" -d "{}"

curl.exe -s -X POST http://127.0.0.1:8765/observe `
  -H "Authorization: Bearer $env:HOPA_BRIDGE_TOKEN" `
  -H "X-Hopa-Role: 2in1" -H "Content-Type: application/json" -d "{}"

# hdc tunnel targets
hdc tconn 127.0.0.1:5556
hdc -t 127.0.0.1:5556 shell "echo phone-ok"

hdc tconn 127.0.0.1:5557
hdc -t 127.0.0.1:5557 shell "echo laptop-ok"
```

`.env` (untracked) currently includes:

```dotenv
HOPA_POOL=1
HOPA_LAPTOP_DEVICE=3QC0225821000268
HOPA_LAPTOP_CLOUD=1
HOPA_LAPTOP_CLOUD_URL=https://hopa-relay.onrender.com
HOPA_LAPTOP_TUNNEL=1
HOPA_LAPTOP_TUNNEL_LISTEN=127.0.0.1:5557
HOPA_LAPTOP_TUNNEL_SESSION=laptop
HOPA_TUNNEL=1
HOPA_BRIDGE_TARGET=127.0.0.1:5556
```

Cloud laptop token defaults to `HOPA_BRIDGE_TOKEN`; no separate laptop token is
needed for the relay because the pool routes by `X-Hopa-Role`.

---

## 7. Known limitations / do not do

- **Do not restart the PC agent before `git stash pop`.** The live processes
  use the WIP; the on-disk files do not have the laptop tunnel target.
- Do not uninstall the laptop app; its data was preserved and the signing
  identity is stable.
- The phone tunnel survives short backgrounding; HarmonyOS can freeze the app
  after a few minutes with the screen off. Open HOPA to reconnect.
- The laptop app currently has no tunnel status UI; the PC per-session
  `/health.tunnel.links` is the diagnostic.
- Both devices share the phone token for the relay. A separate laptop token
  would need a relay token-to-role map (not implemented).
- The plan still has two platform-blocked boxes:
  1. Pushed static arm64 forwarder — SELinux blocks execution from
     `/data/local/tmp`.
  2. 10-minute screen-off hold — the WebSocket stays ready but HarmonyOS
     suspends the app’s JS/TCP handlers.
