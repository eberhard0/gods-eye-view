#!/usr/bin/env bash
# God's Eye View — self-host setup for Ubuntu/Linux.
# Run from the repo root on your PC:  bash deploy/setup.sh
# Installs Node 26 (if needed), builds the app, and installs a systemd
# service that serves it on 127.0.0.1:4173 (localhost only — Cloudflare
# Tunnel sits in front; see deploy/README.md).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4173}"
SERVICE="gods-eye-view"
RUN_USER="${SUDO_USER:-$USER}"

echo "==> Repo:    $REPO_DIR"
echo "==> Service: $SERVICE  (127.0.0.1:$PORT, user $RUN_USER)"

# 1) Node 26 -----------------------------------------------------------------
need_node=1
if command -v node >/dev/null 2>&1; then
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 26 ] && need_node=0
fi
if [ "$need_node" -eq 1 ]; then
  echo "==> Installing Node 26 via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_26.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "==> Node $(node --version), npm $(npm --version)"

# 2) Dependencies + build ----------------------------------------------------
cd "$REPO_DIR"
echo "==> npm ci"
npm ci
if [ ! -f .env ]; then
  cp .env.example .env
  echo "==> Created .env (keyless defaults). Edit it later to add keys."
fi
echo "==> Building (Cesium — takes a few minutes, needs ~2GB free RAM)..."
npm run build

# 3) systemd service (localhost only) ---------------------------------------
NPM_BIN="$(command -v npm)"
echo "==> Installing systemd unit /etc/systemd/system/${SERVICE}.service"
sudo tee /etc/systemd/system/${SERVICE}.service >/dev/null <<EOF
[Unit]
Description=God's Eye View (localhost:${PORT}, fronted by Cloudflare Tunnel)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${REPO_DIR}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=NODE_ENV=production
ExecStart=${NPM_BIN} run preview -- --host 127.0.0.1 --port ${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ${SERVICE}
sleep 3
sudo systemctl status ${SERVICE} --no-pager | head -12 || true
echo
echo "==> Local check:"
curl -sS -o /dev/null -w "   HTTP %{http_code} from http://127.0.0.1:${PORT}/\n" "http://127.0.0.1:${PORT}/" || \
  echo "   (no response yet — check: journalctl -u ${SERVICE} -e)"
echo
echo "Done. App is live on 127.0.0.1:${PORT}. Next: expose it with Cloudflare — see deploy/README.md."
