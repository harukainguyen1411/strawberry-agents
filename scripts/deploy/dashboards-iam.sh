#!/usr/bin/env bash
# Grant IAM roles to the Cloud Run service account for the test dashboard.
#
# Roles granted:
#   roles/datastore.user      — Firestore read/write (project-level)
#   roles/storage.objectAdmin — GCS read/write scoped to test-artifact
#                               buckets ONLY via gsutil (not project-wide)
#
# Note: roles/firebaseauth.admin is NOT required. Firebase Admin SDK
# verifyIdToken() uses public-key verification against Google's JWKS endpoint
# — it needs no IAM role. Granting firebaseauth.admin would expose user CRUD.
#
# Usage: bash scripts/deploy/dashboards-iam.sh [--project <project-id>]
#
# Safe to run multiple times — bindings are additive and gcloud is idempotent.

set -euo pipefail

PROJECT="myapps-b31ea"
SA_NAME="dashboards-cloudrun"

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
set -- strawberry-test-artifacts-prod strawberry-test-artifacts-staging

echo "==> Granting IAM roles for Test Dashboard (project: $PROJECT)"

# Validate SA exists before any grant.
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" >/dev/null 2>&1; then
  echo "ERROR: service account $SA_EMAIL does not exist in project $PROJECT." >&2
  echo "  Create it first: gcloud iam service-accounts create $SA_NAME --project=$PROJECT" >&2
  exit 1
fi
echo "    [ok] service account $SA_EMAIL verified"

# 1. roles/datastore.user — project-level Firestore access
echo "    [iam] granting roles/datastore.user (project-level)"
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/datastore.user" \
  --condition=None \
  --quiet

# 2. roles/storage.objectAdmin — bucket-scoped only (no project-wide grant)
# GCS bucket-level IAM is set via gsutil, not via gcloud projects, which
# ensures storage.objectAdmin is NOT visible in the project-level IAM policy.
for BUCKET do
  echo "    [iam] granting storage.objectAdmin on gs://$BUCKET to $SA_EMAIL"
  gsutil iam ch "serviceAccount:$SA_EMAIL:objectAdmin" "gs://$BUCKET"
done

echo "==> IAM grants complete."
echo ""
echo "Verify with:"
echo "  gcloud projects get-iam-policy $PROJECT --flatten='bindings[].members' \\"
echo "    --filter='bindings.members:$SA_EMAIL' --format='table(bindings.role)'"
echo ""
echo "Confirm NO project-wide storage.objectAdmin in the output above."
echo "Bucket-level storage.objectAdmin verifiable with:"
for BUCKET do
  echo "  gsutil iam get gs://$BUCKET | grep $SA_EMAIL"
done
