#!/usr/bin/env bash
# Pull the latest code, rebuild, and restart the service.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
echo "==> git pull"; git pull --ff-only
echo "==> npm ci"; npm ci
echo "==> build"; npm run build
echo "==> restart"; sudo systemctl restart gods-eye-view
sudo systemctl status gods-eye-view --no-pager | head -6 || true
echo "Done."
