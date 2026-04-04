#!/usr/bin/env bash
set -euo pipefail

# Deploy strawberry Discord relay to VPS
# Run as: runner@vps

export PATH="$HOME/.npm-global/bin:$PATH"

REPO_DIR="/home/runner/strawberry"
DATA_DIR="/home/runner/data"

echo "=== Strawberry Deploy ==="

# Ensure data directories exist
mkdir -p "$DATA_DIR/discord-events" \
         "$DATA_DIR/discord-responses" \
         "$DATA_DIR/discord-processed"

# Pull latest
cd "$REPO_DIR"
echo ">>> Pulling latest..."
git pull --ff-only

# Install discord-relay dependencies
echo ">>> Installing discord-relay dependencies..."
cd "$REPO_DIR/apps/discord-relay"
npm install --production

# Restart PM2 processes
cd "$REPO_DIR"
echo ">>> Restarting PM2 processes..."
pm2 start ecosystem.config.js --update-env 2>/dev/null || pm2 restart ecosystem.config.js --update-env

# Save PM2 process list for reboot persistence
pm2 save

echo ">>> Deploy complete."
pm2 status
