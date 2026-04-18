#!/usr/bin/env bash
# Create the coder-worker GCE VM.
# Run from any machine with gcloud authenticated.
# Usage: ./scripts/gce/create-coder-vm.sh [--zone ZONE]
set -euo pipefail

PROJECT="myapps-b31ea"
VM_NAME="coder-worker"
ZONE="${1:-us-central1-a}"
MACHINE_TYPE="e2-small"

echo "Creating VM '$VM_NAME' in project '$PROJECT', zone '$ZONE'..."

gcloud compute instances create "$VM_NAME" \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB \
  --tags=coder-worker \
  --metadata=startup-script='#!/bin/bash
    # One-shot startup: install Node.js 20 LTS + git
    if ! command -v node &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs git
    fi
  '

echo ""
echo "VM created. Next steps:"
echo "  1. SSH in:  gcloud compute ssh $VM_NAME --project=$PROJECT --zone=$ZONE"
echo "  2. Run:     sudo /opt/coder-worker/scripts/gce/setup-coder-vm.sh"
echo "  3. Write .env:  sudo -u coder nano /opt/coder-worker/apps/coder-worker/.env"
echo "  4. Auth Claude:  sudo -u coder -i claude login"
echo "  5. Configure git: sudo -u coder git config --global user.name 'coder-worker'"
echo "  6. Start:   sudo systemctl enable --now coder-worker"
