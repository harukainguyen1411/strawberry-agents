#!/usr/bin/env bash
# Pull latest code and restart bee-worker on the GCE VM.
# Run ON the VM as root (or via: gcloud compute ssh bee-worker -- sudo /opt/bee-worker/scripts/gce/update-bee-worker.sh)
set -euo pipefail

INSTALL_DIR="/opt/bee-worker"
WORKER_DIR="$INSTALL_DIR/apps/private-apps/bee-worker"

echo "=== Pulling latest code ==="
sudo -u bee git -C "$INSTALL_DIR" pull --ff-only

echo "=== Installing dependencies ==="
cd "$WORKER_DIR"
sudo -u bee npm ci

echo "=== Building ==="
sudo -u bee npm run build

echo "=== Restarting service ==="
systemctl restart bee-worker

echo "=== Done ==="
journalctl -u bee-worker -n 5 --no-pager
