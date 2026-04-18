#!/usr/bin/env bash
# Run ON the GCE VM as root after initial creation.
# Sets up the bee user, clones the repo, installs deps, and configures systemd.
# Usage: sudo ./scripts/gce/setup-bee-vm.sh
set -euo pipefail

REPO_URL="https://github.com/Duongntd/strawberry.git"
INSTALL_DIR="/opt/bee-worker"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root" >&2
  exit 1
fi

echo "=== Creating bee user ==="
if ! id bee &>/dev/null; then
  useradd -r -m -d "$INSTALL_DIR" -s /bin/bash bee
  echo "Created user 'bee' with home $INSTALL_DIR"
else
  echo "User 'bee' already exists"
fi

echo "=== Cloning repo ==="
if [ ! -d "$INSTALL_DIR/.git" ]; then
  sudo -u bee git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "Repo already cloned, pulling latest..."
  sudo -u bee git -C "$INSTALL_DIR" pull --ff-only
fi

echo "=== Installing npm dependencies ==="
cd "$INSTALL_DIR/apps/private-apps/bee-worker"
sudo -u bee npm ci
sudo -u bee npm run build

echo "=== Installing systemd unit ==="
cp "$INSTALL_DIR/scripts/gce/bee-worker.service" /etc/systemd/system/bee-worker.service
systemctl daemon-reload

echo "=== Installing health check cron ==="
cp "$INSTALL_DIR/scripts/gce/bee-health-check.sh" /opt/bee-worker/bee-health-check.sh
chmod +x /opt/bee-worker/bee-health-check.sh
# Run health check every 6 hours
CRON_LINE="0 */6 * * * /opt/bee-worker/bee-health-check.sh >> /var/log/bee-worker/auth-health.log 2>&1"
(crontab -u bee -l 2>/dev/null | grep -v bee-health-check; echo "$CRON_LINE") | crontab -u bee -

echo "=== Creating log directory ==="
mkdir -p /var/log/bee-worker
chown bee:bee /var/log/bee-worker

echo "=== Creating work directory ==="
mkdir -p /tmp/bee
chown bee:bee /tmp/bee

echo ""
echo "Setup complete. Remaining manual steps:"
echo "  1. Write .env:         sudo -u bee nano $INSTALL_DIR/apps/private-apps/bee-worker/.env"
echo "     (see $INSTALL_DIR/scripts/gce/.env.example)"
echo "  2. Auth Claude Code:   sudo -u bee -i claude login"
echo "  3. Start service:      sudo systemctl enable --now bee-worker"
echo "  4. Check logs:         journalctl -u bee-worker -f"
