---
status: approved
owner: bard
created: 2026-04-11
title: Install Cloudflare and GCP MCP servers
---

# Install Cloudflare and GCP MCP Servers

## Goal

Add Cloudflare DNS management and Google Cloud Platform management capabilities to the Claude Code CLI setup via MCP servers.

## Selected Servers

### Cloudflare: `@cloudflare/mcp-server-cloudflare` (v0.2.0)

- Official Cloudflare package on npm
- Covers DNS, Workers, KV, R2, D1, and other Cloudflare APIs
- Requires `CLOUDFLARE_API_TOKEN` env var (we have this in `secrets/cloudflare.env`)
- Runs via `npx -y @cloudflare/mcp-server-cloudflare`

### GCP: `@google-cloud/gcloud-mcp` (v0.5.3)

- Official Google Cloud package on npm
- Wraps the `gcloud` CLI — natural language interface to all GCP services
- Requires `gcloud` CLI to be installed and authenticated (`gcloud auth login`)
- Runs via `npx -y @google-cloud/gcloud-mcp`
- No separate API key needed — uses the local gcloud credential chain

## Compatibility

Both servers use stdio transport, matching our existing MCP pattern (evelynn, discord). Both run via `npx`, same as the discord MCP. No conflicts with existing plugin list (plugins are Claude Code plugins, not project MCPs — they coexist in separate config files).

## Implementation Steps

### 1. Create wrapper scripts

Follow the pattern established in `mcps/discord/scripts/start.sh`.

**`mcps/cloudflare/scripts/start.sh`:**
```bash
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
```

**`mcps/gcp/scripts/start.sh`:**
```bash
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
```

### 2. Create README files

Create `mcps/cloudflare/README.md` and `mcps/gcp/README.md` with server purpose, prerequisites, and env var requirements.

### 3. Register in `.mcp.json`

Add both servers to the project `.mcp.json`:

```json
"cloudflare": {
  "type": "stdio",
  "command": "bash",
  "args": [
    "/Users/duongntd99/Documents/Personal/strawberry/mcps/cloudflare/scripts/start.sh"
  ],
  "env": {}
},
"gcp": {
  "type": "stdio",
  "command": "bash",
  "args": [
    "/Users/duongntd99/Documents/Personal/strawberry/mcps/gcp/scripts/start.sh"
  ],
  "env": {}
}
```

### 4. Make scripts executable

```bash
chmod +x mcps/cloudflare/scripts/start.sh mcps/gcp/scripts/start.sh
```

### 5. Smoke test

Start a new Claude Code session and verify both MCP servers appear in the tool list. Test a simple read-only command for each:
- Cloudflare: list DNS zones
- GCP: `gcloud projects list` equivalent

## Prerequisites

- `secrets/cloudflare.env` must exist with `CF_API_TOKEN=...` (already present)
- `gcloud` CLI must be installed and authenticated on the Mac
- npm/npx available (already present)

## Single commit

All files land in one `chore:` commit directly to main.
