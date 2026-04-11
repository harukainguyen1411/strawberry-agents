#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_FILE="$REPO_ROOT/secrets/cloudflare.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "cloudflare-mcp: missing $ENV_FILE" >&2
  exit 1
fi

# Source the env file to get CF_API_TOKEN
set -a
. "$ENV_FILE"
set +a

if [[ -z "${CF_API_TOKEN:-}" ]]; then
  echo "cloudflare-mcp: CF_API_TOKEN not set in $ENV_FILE" >&2
  exit 1
fi

export CLOUDFLARE_API_TOKEN="$CF_API_TOKEN"
exec npx -y @cloudflare/mcp-server-cloudflare
