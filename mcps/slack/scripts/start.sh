#!/usr/bin/env bash
# Canonical single-secret MCP start script — reference template for T-new-D.
# Pattern: §4.2 of plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md
#
# How it works:
#   1. REPO_ROOT resolves to the strawberry-agents repo root (3 levels up from here).
#   2. Non-secret config vars are exported before the exec so they reach the child.
#   3. tools/decrypt.sh reads the age-encrypted ciphertext from stdin (< redirect),
#      decrypts it, writes SLACK_USER_TOKEN to secrets/work/runtime/slack.env
#      (gitignored runtime path), then exec-replaces this shell with the MCP runner
#      process — SLACK_USER_TOKEN lives in the child env only, never in argv or
#      parent-shell memory.
#   4. No $(…) capture of the secret anywhere in this script.
#
# Copy-paste guide for subsequent single-secret MCP migrations:
#   - Replace SLACK_USER_TOKEN with the target env var name.
#   - Replace secrets/work/encrypted/slack-user-token.age with the right blob.
#   - Replace secrets/work/runtime/slack.env with the right runtime path.
#   - Replace the runner (mcps/slack/node_modules/.bin/tsx mcps/slack/src/server.ts)
#     with the target MCP's runner command (uv run, uvx, node, etc.).
#   - Add or remove non-secret env-var exports as needed.
#   - Adjust the dependency-check block for the MCP's toolchain (npm/uv/etc.).
#
# This start.sh will fail until P1-T2 creates secrets/work/encrypted/slack-user-token.age.
# That is expected — the script structure is the deliverable, not end-to-end operation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

# ── dependency check (non-secret, safe to run before exec) ──────────────────
MCP_DIR="$REPO_ROOT/mcps/slack"
if [ ! -x "$MCP_DIR/node_modules/.bin/tsx" ]; then
    echo "slack-mcp: installing dependencies..." >&2
    npm install --silent --prefix "$MCP_DIR"
fi

# ── non-secret config (exported into child env via normal inheritance) ───────
export SLACK_TEAM_ID="${SLACK_TEAM_ID:-T18MLBHC5}"
export DUONG_USER_ID="${DUONG_USER_ID:-U03KDE6SS9J}"

# ── decrypt + exec (plaintext stays in child env only) ───────────────────────
exec ./tools/decrypt.sh \
    --target "secrets/work/runtime/slack.env" \
    --var    "SLACK_USER_TOKEN" \
    --exec -- \
        "$MCP_DIR/node_modules/.bin/tsx" \
        "$MCP_DIR/src/server.ts" \
    < "secrets/work/encrypted/slack-user-token.age"
