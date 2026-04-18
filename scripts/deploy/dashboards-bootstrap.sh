#!/usr/bin/env bash
# Idempotent bootstrap for Test Dashboard GCS buckets.
# Creates strawberry-test-artifacts-prod and strawberry-test-artifacts-staging,
# applies the 90-day lifecycle rule (runs/ prefix only; pinned/ objects are
# excluded by design — D4 moves pinned artifacts under pinned/ which is not
# covered by the runs/ prefix lifecycle condition), and scopes IAM to the
# Cloud Run service account.
#
# Usage: bash scripts/deploy/dashboards-bootstrap.sh [--project <project-id>]
#
# Safe to run multiple times — second run is a no-op.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROJECT="myapps-b31ea"
REGION="us-central1"
SA_NAME="dashboards-cloudrun"

# Lifecycle policy path relative to repo root
LIFECYCLE_JSON="$REPO_ROOT/dashboards/server/config/gcs-lifecycle.json"

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SA_EMAIL="$SA_NAME@$PROJECT.iam.gserviceaccount.com"

BUCKETS="strawberry-test-artifacts-prod strawberry-test-artifacts-staging"

echo "==> Bootstrapping Test Dashboard GCS buckets (project: $PROJECT)"

# Validate the Cloud Run service account exists before touching any buckets.
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" >/dev/null 2>&1; then
  echo "ERROR: service account $SA_EMAIL does not exist in project $PROJECT." >&2
  echo "  Create it first: gcloud iam service-accounts create $SA_NAME --project=$PROJECT" >&2
  exit 1
fi
echo "    [ok] service account $SA_EMAIL verified"

for BUCKET in $BUCKETS; do
  # Create bucket if it does not exist
  if gsutil ls -b "gs://$BUCKET" >/dev/null 2>&1; then
    echo "    [skip] gs://$BUCKET already exists"
  else
    echo "    [create] gs://$BUCKET"
    gsutil mb -p "$PROJECT" -l "$REGION" "gs://$BUCKET"
    # Disable public access (belt + suspenders alongside uniform bucket-level ACL)
    gsutil pap set enforced "gs://$BUCKET"
  fi

  # Apply lifecycle policy (idempotent — gsutil lifecycle set is always a PUT)
  echo "    [lifecycle] applying 90-day rule to gs://$BUCKET"
  gsutil lifecycle set "$LIFECYCLE_JSON" "gs://$BUCKET"

  # Scope IAM to the Cloud Run service account (objectAdmin on this bucket only)
  # Check if binding already exists to keep output clean
  EXISTING=$(gsutil iam get "gs://$BUCKET" 2>/dev/null | grep -c "serviceAccount:$SA_EMAIL" || true)
  if [ "$EXISTING" -gt 0 ]; then
    echo "    [skip] IAM binding for $SA_EMAIL already present on gs://$BUCKET"
  else
    echo "    [iam] granting storage.objectAdmin on gs://$BUCKET to $SA_EMAIL"
    gsutil iam ch "serviceAccount:$SA_EMAIL:objectAdmin" "gs://$BUCKET"
  fi
done

echo "==> Bootstrap complete."
echo ""
echo "Verify with:"
for BUCKET in $BUCKETS; do
  echo "  gsutil lifecycle get gs://$BUCKET"
done
