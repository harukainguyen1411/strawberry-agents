#!/usr/bin/env bash
set -euo pipefail

# Verify gcloud is available
if ! command -v gcloud &>/dev/null; then
  echo "gcp-mcp: gcloud CLI not found — install from https://cloud.google.com/sdk" >&2
  exit 1
fi

# Verify authenticated
if ! gcloud auth print-access-token &>/dev/null 2>&1; then
  echo "gcp-mcp: not authenticated — run 'gcloud auth login'" >&2
  exit 1
fi

exec npx -y @google-cloud/gcloud-mcp
