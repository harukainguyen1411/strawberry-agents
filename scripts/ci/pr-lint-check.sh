#!/bin/sh
# pr-lint-check.sh — PR body linter for Rule 16 (Akali / Playwright MCP gate)
#
# XFAIL STUB: Implementation ships in T4. This stub always exits 2 (not implemented)
# so that the test runner correctly reports xfail state before T4 lands.
#
# Usage:
#   PR_BODY="<body text>" CHANGED_FILES="<newline-separated paths>" sh scripts/ci/pr-lint-check.sh
#
# Exit codes:
#   0 — PR is exempt or has required QA-Report:/QA-Waiver: marker
#   1 — PR is UI/user-flow but missing required marker (Rule 16 violation)
#   2 — not implemented (xfail stub only)

echo "pr-lint-check.sh: NOT IMPLEMENTED (xfail stub — T4 ships the implementation)" >&2
exit 2
