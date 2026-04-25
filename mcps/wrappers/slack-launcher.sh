#!/usr/bin/env bash
# mcps/wrappers/slack-launcher.sh
#
# Wraps the UNMODIFIED company-shared Slack MCP at:
#   ~/Documents/Work/mmp/workspace/mcps/slack/
#
# DO NOT modify any file under ~/Documents/Work/mmp/workspace/mcps/slack/.
# That directory is a company-shared repo. Other engineers depend on it as-is.
# This wrapper is OUR strawberry-agents-scoped decryption shim — it injects
# SLACK_USER_TOKEN into the child process env and execs the upstream entrypoint.
#
# Architecture (from plans/in-progress/work/2026-04-24-sona-secretary-mcp-suite.md §4.2):
#   1. Reads age-encrypted blob from $STRAWBERRY_AGENTS/secrets/work/encrypted/slack-user-token.age
#   2. Pipes ciphertext to tools/decrypt.sh --target secrets/work/runtime/slack.env
#                                            --var SLACK_USER_TOKEN --exec --
#   3. decrypt.sh execs $UPSTREAM_START with SLACK_USER_TOKEN in the child env only.
#
# Plaintext discipline:
#   - Decrypted token NEVER appears in stdout, parent shell env, or argv.
#   - Runtime env-file at secrets/work/runtime/slack.env is mode 0600 (enforced
#     by decrypt.sh) and gitignored.
#
# Env overrides:
#   STRAWBERRY_AGENTS   Path to the strawberry-agents repo root.
#                       Default: directory containing this script's parent.
#   UPSTREAM_START      Path to the upstream Slack MCP entrypoint.
#                       Default: $HOME/Documents/Work/mmp/workspace/mcps/slack/scripts/start.sh
#   SLACK_AGE_BLOB      Path to the age-encrypted Slack token blob.
#                       Default: $STRAWBERRY_AGENTS/secrets/work/encrypted/slack-user-token.age
#
# Usage (registered in ~/Documents/Work/mmp/workspace/.mcp.json):
#   "command": "/path/to/strawberry-agents/mcps/wrappers/slack-launcher.sh"

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve repo root (POSIX-portable: no readlink -f dependency)
# ---------------------------------------------------------------------------
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STRAWBERRY_AGENTS="${STRAWBERRY_AGENTS:-$(cd "$_SCRIPT_DIR/../.." && pwd)}"

if [ ! -d "$STRAWBERRY_AGENTS" ]; then
    printf 'slack-launcher: STRAWBERRY_AGENTS not found: %s\n' "$STRAWBERRY_AGENTS" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Locate decrypt tool
# ---------------------------------------------------------------------------
DECRYPT_SH="$STRAWBERRY_AGENTS/tools/decrypt.sh"
if [ ! -x "$DECRYPT_SH" ]; then
    printf 'slack-launcher: decrypt.sh not found or not executable: %s\n' "$DECRYPT_SH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Locate age-encrypted Slack token blob
# ---------------------------------------------------------------------------
SLACK_AGE_BLOB="${SLACK_AGE_BLOB:-$STRAWBERRY_AGENTS/secrets/work/encrypted/slack-user-token.age}"
if [ ! -f "$SLACK_AGE_BLOB" ]; then
    printf 'slack-launcher: age blob not found: %s\n' "$SLACK_AGE_BLOB" >&2
    printf 'slack-launcher: provision the blob with: age -e -R secrets/recipients.txt -o secrets/work/encrypted/slack-user-token.age\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Locate upstream Slack MCP entrypoint (DO NOT MODIFY the upstream files)
# ---------------------------------------------------------------------------
UPSTREAM_START="${UPSTREAM_START:-$HOME/Documents/Work/mmp/workspace/mcps/slack/scripts/start.sh}"
if [ ! -f "$UPSTREAM_START" ]; then
    printf 'slack-launcher: upstream entrypoint not found: %s\n' "$UPSTREAM_START" >&2
    printf 'slack-launcher: override with UPSTREAM_START env var if installed elsewhere\n' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Decrypt and exec — ciphertext arrives on stdin via redirection.
# tools/decrypt.sh writes SLACK_USER_TOKEN to secrets/work/runtime/slack.env
# (mode 0600, gitignored) and then execs the upstream with env injected.
# Plaintext never appears in parent shell memory or stdout after this point.
# ---------------------------------------------------------------------------
cd "$STRAWBERRY_AGENTS"
exec "$DECRYPT_SH" \
    --target "secrets/work/runtime/slack.env" \
    --var    "SLACK_USER_TOKEN" \
    --exec -- "$UPSTREAM_START" \
    < "$SLACK_AGE_BLOB"
