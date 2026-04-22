#!/bin/sh
# pr-lint-check.sh — PR body linter for Rule 16 (Akali / Playwright MCP gate)
#
# Classifies a PR as UI, user-flow, or exempt and enforces that UI/user-flow
# PRs include either a QA-Report: or QA-Waiver: marker in the PR body.
#
# Usage (standalone):
#   PR_BODY="<body text>" CHANGED_FILES="<newline-separated paths>" sh scripts/ci/pr-lint-check.sh
#
# Usage (from GitHub Actions — variables injected by workflow):
#   Same env vars; workflow fetches PR body and changed files then calls this script.
#
# Exit codes:
#   0 — PR is exempt or has required QA-Report:/QA-Waiver: marker
#   1 — PR is UI/user-flow but missing required marker (Rule 16 violation)

set -u

PR_BODY="${PR_BODY:-}"
CHANGED_FILES="${CHANGED_FILES:-}"

# ---------------------------------------------------------------------------
# 1. Classify by changed file paths against UI/user-flow path allowlist
# ---------------------------------------------------------------------------
is_ui_or_flow=0

# UI path patterns (POSIX glob-style checked via case statement)
check_file_path() {
    f="$1"
    case "$f" in
        apps/*/app/*|apps/*/components/*|apps/*/pages/*|apps/*/routes/*|apps/*/forms/*|apps/*/auth/*|apps/*/session/*)
            return 0
            ;;
    esac
    return 1
}

if [ -n "$CHANGED_FILES" ]; then
    OLD_IFS="$IFS"
    IFS='
'
    for filepath in $CHANGED_FILES; do
        if check_file_path "$filepath"; then
            is_ui_or_flow=1
            break
        fi
    done
    IFS="$OLD_IFS"
fi

# ---------------------------------------------------------------------------
# 2. Classify by user-flow keywords in PR body
# ---------------------------------------------------------------------------
if [ "$is_ui_or_flow" = "0" ] && [ -n "$PR_BODY" ]; then
    # Check for user-flow keywords (case-insensitive via tr)
    body_lower=$(printf '%s' "$PR_BODY" | tr '[:upper:]' '[:lower:]')
    case "$body_lower" in
        *"new route"*|*"new form"*|*"state transition"*|*"auth flow"*|*"session lifecycle"*|*"user flow"*)
            is_ui_or_flow=1
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# 3. Exempt — not UI or user-flow
# ---------------------------------------------------------------------------
if [ "$is_ui_or_flow" = "0" ]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 4. UI/user-flow PR — require QA-Report: or QA-Waiver: in body
# ---------------------------------------------------------------------------
has_marker=0
case "$PR_BODY" in
    *"QA-Report:"*|*"QA-Waiver:"*)
        has_marker=1
        ;;
esac

if [ "$has_marker" = "1" ]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 5. Violation — missing required marker
# ---------------------------------------------------------------------------
cat >&2 <<'MSG'
Rule 16 violation: This PR touches UI or user-flow paths but is missing a
QA-Report: or QA-Waiver: entry in the PR body.

Required action: Run Akali via Playwright MCP to produce a QA report, then
add one of the following lines to your PR description:
  QA-Report: assessments/qa-reports/<date>-akali-<slug>.md
  QA-Waiver: <reason>

See CLAUDE.md Rule 16 and .claude/agents/akali.md for details.
MSG
exit 1
