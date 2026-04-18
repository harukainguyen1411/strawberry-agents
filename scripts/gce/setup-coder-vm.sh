#!/usr/bin/env bash
# Run ON the GCE VM as root after initial creation.
# Sets up the coder user, clones the repo, installs deps, and configures systemd.
# Usage: sudo ./scripts/gce/setup-coder-vm.sh
set -euo pipefail

REPO_URL="https://github.com/Duongntd/strawberry.git"
INSTALL_DIR="/opt/coder-worker"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root" >&2
  exit 1
fi

echo "=== Creating coder user ==="
if ! id coder &>/dev/null; then
  useradd -r -m -d "$INSTALL_DIR" -s /bin/bash coder
  echo "Created user 'coder' with home $INSTALL_DIR"
else
  echo "User 'coder' already exists"
fi

echo "=== Cloning repo ==="
if [ ! -d "$INSTALL_DIR/.git" ]; then
  sudo -u coder git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "Repo already cloned, pulling latest..."
  sudo -u coder git -C "$INSTALL_DIR" pull --ff-only
fi

echo "=== Configuring git for push ==="
sudo -u coder git -C "$INSTALL_DIR" config user.name "coder-worker"
sudo -u coder git -C "$INSTALL_DIR" config user.email "coder-worker@darkstrawberry.com"

echo "=== Installing npm dependencies ==="
cd "$INSTALL_DIR/apps/coder-worker"
sudo -u coder npm ci
sudo -u coder npm run build

echo "=== Installing systemd unit ==="
cp "$INSTALL_DIR/scripts/gce/coder-worker.service" /etc/systemd/system/coder-worker.service
systemctl daemon-reload

echo "=== Installing health check cron ==="
cp "$INSTALL_DIR/scripts/gce/coder-health-check.sh" /opt/coder-worker/coder-health-check.sh
chmod +x /opt/coder-worker/coder-health-check.sh
CRON_LINE="0 */6 * * * /opt/coder-worker/coder-health-check.sh >> /var/log/coder-worker/auth-health.log 2>&1"
(crontab -u coder -l 2>/dev/null | grep -v coder-health-check; echo "$CRON_LINE") | crontab -u coder -

echo "=== Creating log directory ==="
mkdir -p /var/log/coder-worker
chown coder:coder /var/log/coder-worker

echo ""
echo "Setup complete. Remaining manual steps:"
echo "  1. Write .env:         sudo -u coder nano $INSTALL_DIR/apps/coder-worker/.env"
echo "     (see $INSTALL_DIR/scripts/gce/.env.coder.example)"
echo "  2. Configure git auth: sudo -u coder git -C $INSTALL_DIR remote set-url origin https://<TOKEN>@github.com/Duongntd/strawberry.git"
echo "     (or use a credential helper)"
echo "  3. Auth Claude Code:   sudo -u coder -i claude login"
echo "  4. Start service:      sudo systemctl enable --now coder-worker"
echo "  5. Check logs:         journalctl -u coder-worker -f"
