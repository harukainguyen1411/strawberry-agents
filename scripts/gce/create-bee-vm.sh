#!/usr/bin/env bash
# Create the bee-worker GCE VM.
# Run from any machine with gcloud authenticated.
# Usage: ./scripts/gce/create-bee-vm.sh [--zone ZONE]
set -euo pipefail

PROJECT="myapps-b31ea"
VM_NAME="bee-worker"
ZONE="${1:-us-central1-a}"
MACHINE_TYPE="e2-micro"

echo "Creating VM '$VM_NAME' in project '$PROJECT', zone '$ZONE'..."

gcloud compute instances create "$VM_NAME" \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --tags=bee-worker \
  --metadata=startup-script='#!/bin/bash
    # One-shot startup: install Node.js 20 LTS
    if ! command -v node &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs git
    fi
  '

echo ""
echo "VM created. Next steps:"
echo "  1. SSH in:  gcloud compute ssh $VM_NAME --project=$PROJECT --zone=$ZONE"
echo "  2. Run:     sudo /opt/bee-worker/scripts/gce/setup-bee-vm.sh"
echo "  3. Write .env:  sudo -u bee nano /opt/bee-worker/.env"
echo "  4. Auth Claude:  sudo -u bee claude login"
echo "  5. Start:   sudo systemctl enable --now bee-worker"
