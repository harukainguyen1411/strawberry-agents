#!/usr/bin/env bash
# Pull latest code and restart coder-worker on the GCE VM.
# Run ON the VM as root.
set -euo pipefail

INSTALL_DIR="/opt/coder-worker"
WORKER_DIR="$INSTALL_DIR/apps/coder-worker"

echo "=== Pulling latest code ==="
sudo -u coder git -C "$INSTALL_DIR" pull --ff-only

echo "=== Installing dependencies ==="
cd "$WORKER_DIR"
sudo -u coder npm ci

echo "=== Building ==="
sudo -u coder npm run build

echo "=== Restarting service ==="
systemctl restart coder-worker

echo "=== Done ==="
journalctl -u coder-worker -n 5 --no-pager
