#!/usr/bin/env bash
# scripts/tests/probe-upstream-slack.sh
#
# Upstream probe shim used by wrapper-slack-launcher.bats smoke test.
# Replaces the real Slack MCP entrypoint during testing (via UPSTREAM_START override).
#
# Contract:
#   - Asserts SLACK_USER_TOKEN is set in env (fails loudly if not)
#   - Writes the token value to $PROBE_MARKER_FILE (set by caller)
#   - Exits 0 on success
#
# This script must NOT be run directly against real credentials.
# It is a test fixture — invoked only via UPSTREAM_START override in bats tests.

set -euo pipefail

if [ -z "${SLACK_USER_TOKEN:-}" ]; then
    printf 'probe-upstream-slack: SLACK_USER_TOKEN is not set in env\n' >&2
    exit 1
fi

if [ -z "${PROBE_MARKER_FILE:-}" ]; then
    printf 'probe-upstream-slack: PROBE_MARKER_FILE not set — cannot write marker\n' >&2
    exit 1
fi

# Write the token value to the marker file so the test can assert it
printf '%s' "$SLACK_USER_TOKEN" > "$PROBE_MARKER_FILE"

exit 0
