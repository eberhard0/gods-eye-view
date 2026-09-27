# Self-hosting God's Eye View (Ubuntu + Cloudflare)

Runs the full app — 3D globe **and** the live-data proxy (fires, cyclones,
CCTV, flights, ships, weather…) — on your own PC, served on your domain
through a Cloudflare Tunnel, gated to your team with Cloudflare Access.

```
 browsers (iPhone/Android/desktop)
        │ https://globe.YOURDOMAIN.com
        ▼
   Cloudflare edge  — TLS + Access (email gate)
        │ encrypted tunnel, no open ports
        ▼
   your PC: Node 26  →  127.0.0.1:4173  (localhost only)
```

## 1. Run the app locally

```bash
git clone https://github.com/eberhard0/gods-eye-view
cd gods-eye-view
bash deploy/setup.sh
```

This installs Node 26 (if needed), builds, and installs a **systemd** service
(`gods-eye-view`) serving `127.0.0.1:4173` via `npm run preview`. It restarts on
crash and on reboot. Starts **keyless** — no API keys required.

Handy: `journalctl -u gods-eye-view -e` (logs) · `sudo systemctl restart gods-eye-view`
· `bash deploy/update.sh` (pull + rebuild + restart).

## 2. Expose it with a Cloudflare Tunnel

```bash
# install cloudflared
curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

cloudflared tunnel login                       # opens a URL — approve YOURDOMAIN
cloudflared tunnel create gods-eye-view        # note the UUID it prints
cloudflared tunnel route dns gods-eye-view globe.YOURDOMAIN.com
```

Create `~/.cloudflared/config.yml` (replace UUID, USER, domain):

```yaml
tunnel: <TUNNEL-UUID>
credentials-file: /home/USER/.cloudflared/<TUNNEL-UUID>.json
ingress:
  - hostname: globe.YOURDOMAIN.com
    service: http://127.0.0.1:4173
    originRequest:
      # REQUIRED: the app only accepts Host: localhost, so rewrite it here.
      httpHostHeader: localhost
  - service: http_status:404
```

Run it as a service:

```bash
sudo cloudflared --config /home/USER/.cloudflared/config.yml service install
sudo systemctl enable --now cloudflared
```

`https://globe.YOURDOMAIN.com` should now load the globe.

> The `httpHostHeader: localhost` line is not optional — the app's server
> only allows the `localhost` host header, so without it Cloudflare's requests
> come in as your public domain and get "Blocked request".

## 3. Lock it down with Cloudflare Access (do this before adding any keys)

In **one.dash.cloudflare.com → Zero Trust → Access → Applications**:

1. **Add an application → Self-hosted.**
2. Subdomain `globe`, domain `YOURDOMAIN.com`.
3. Add a policy: **Action = Allow**, Include → **Emails ending in** `@kompastv.com`
   (your real staff domain), or list specific emails.
4. Save. Visitors now get a Cloudflare login (email one-time code); only your
   team gets through.

## 4. Adding keys later (optional, all off by default)

Edit `.env` (see `.env.example`), then `bash deploy/update.sh`.

- **Cesium ion token** (free tier) → Google Photorealistic **3D cities**.
- **NASA FIRMS / AISStream / TomTom / OpenSky** (free) → richer fire/ship/traffic.
- **OpenAI** → voice control (metered; has an in-app $5 hard cap).

**Because a shared instance brokers your keys/quota to whoever can reach it:**
keep Access on; set the in-app per-IP limits (`GEV_RATELIMIT_*` in `.env`); and
set **provider-side billing caps** — app throttles are not billing caps.

⚠️ **Commercial use:** KompasTV is commercial, so Google Photorealistic 3D Tiles
and several bundled datasets need their terms checked before on-air use — the
free Cesium ion tier is non-commercial. Keyless Esri/OSM imagery is fine to start.

## Notes
- The PC must stay awake for the team to reach the tool (disable sleep for a
  server role). Fine for desk research; think twice before making it a live
  on-air dependency.
- Fork of https://github.com/bilawalsidhu/gods-eye-view (MIT). Keep upstream
  attribution intact.
