#!/usr/bin/env bats
# scripts/tests/wrapper-slack-launcher.bats
# Plan: plans/in-progress/work/2026-04-24-sona-secretary-mcp-suite.md / T-new-D
#
# xfail stub — wrapper does not yet exist.
# This test is intentionally failing (skip with todo) to satisfy Rule 12:
# xfail commit must land before the implementation commit on the same branch.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ---------------------------------------------------------------------------
# xfail: wrapper file existence
# ---------------------------------------------------------------------------
@test "T-new-D xfail: mcps/wrappers/slack-launcher.sh does not yet exist" {
    skip "xfail — Plan: 2026-04-24-sona-secretary-mcp-suite.md T-new-D not yet implemented"
    [ -f "$REPO_ROOT/mcps/wrappers/slack-launcher.sh" ]
}

# ---------------------------------------------------------------------------
# xfail: wrapper end-to-end exec
# ---------------------------------------------------------------------------
@test "T-new-D xfail: wrapper execs upstream with SLACK_USER_TOKEN in env" {
    skip "xfail — Plan: 2026-04-24-sona-secretary-mcp-suite.md T-new-D not yet implemented"
    run bash "$REPO_ROOT/mcps/wrappers/slack-launcher.sh"
    [ "$status" -eq 0 ]
}
