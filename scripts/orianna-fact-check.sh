#!/usr/bin/env bash
# orianna-fact-check.sh — LLM-backed plan fact-check gate.
#
# Primary path: invokes Orianna via the claude CLI as a non-interactive
# subagent. Falls back to scripts/fact-check-plan.sh (pure-bash mechanical
# check) when the claude CLI is unavailable (Duong decision 4).
#
# Contract: agents/orianna/claim-contract.md (v1)
# Prompt:   agents/orianna/prompts/plan-check.md (sourced at runtime)
#
# Usage:
#   ./scripts/orianna-fact-check.sh <plan-path.md>
#
# Exit codes:
#   0 — no block findings
#   1 — one or more block findings
#   2 — invocation error (bad args, missing file, CLI crash, timeout)
#
# Report written to: assessments/plan-fact-checks/<basename>-<ISO-timestamp>.md
# Report is always written, even on exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- helpers ---------------------------------------------------------------

log_stderr() { printf '[orianna-fact-check] %s\n' "$*" >&2; }

die() {
  log_stderr "ERROR: $*"
  exit 2
}

usage() {
  cat >&2 <<EOF
Usage: $0 <plan-path.md>

Fact-checks a plan using Orianna (LLM path via claude CLI). Falls back to
scripts/fact-check-plan.sh if claude CLI is not available.

Exit codes: 0=clean, 1=block findings, 2=invocation error
Report: assessments/plan-fact-checks/<basename>-<ISO-timestamp>.md
EOF
  exit 2
}

# ---- argument validation ---------------------------------------------------

[ $# -eq 1 ] || usage
PLAN_PATH="$1"

# Accept absolute or relative path.
case "$PLAN_PATH" in
  /*) ;;
  *)  PLAN_PATH="$REPO_ROOT/$PLAN_PATH" ;;
esac

[ -f "$PLAN_PATH" ] || die "plan file not found: $PLAN_PATH"
case "$PLAN_PATH" in
  *.md) ;;
  *)    die "plan file must end in .md (got $PLAN_PATH)" ;;
esac

PLAN_REL="${PLAN_PATH#"$REPO_ROOT/"}"

# ---- claude CLI check ------------------------------------------------------

if ! command -v claude >/dev/null 2>&1; then
  log_stderr "claude CLI not found, falling back to mechanical check"
  exec "$SCRIPT_DIR/fact-check-plan.sh" "$PLAN_PATH"
  # exec replaces this process; lines below are unreachable on success.
  exit 2  # reached only if exec itself fails
fi

# ---- source pinned prompt --------------------------------------------------

PROMPT_FILE="$REPO_ROOT/agents/orianna/prompts/plan-check.md"
[ -f "$PROMPT_FILE" ] || die "pinned prompt not found: $PROMPT_FILE"
PROMPT=$(cat "$PROMPT_FILE")

# Append the plan path to the prompt so Orianna knows what to check.
FULL_PROMPT="${PROMPT}

---

## Plan to check

Plan path (relative to repo root): \`${PLAN_REL}\`
Absolute path: \`${PLAN_PATH}\`

Begin the fact-check now. Read the plan, extract claims, verify each one,
and write the report to assessments/plan-fact-checks/ as specified above.
Then exit with the appropriate status code (0=clean, 1=block, 2=error).
"

# ---- invoke orianna ---------------------------------------------------------

log_stderr "invoking Orianna (claude CLI) on: $PLAN_REL"

REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

# Run claude with a timeout. We capture exit code; non-zero exit codes from
# claude may mean block findings (1) or invocation error (2).
claude_exit=0
claude \
  -p \
  --dangerously-skip-permissions \
  --system-prompt "You are Orianna, the fact-checker for the strawberry agent system. Your working directory is $REPO_ROOT." \
  "$FULL_PROMPT" \
  2>>"$REPO_ROOT/.orianna-stderr.tmp" || claude_exit=$?

# Cleanup temp stderr file (it may have login noise etc.)
rm -f "$REPO_ROOT/.orianna-stderr.tmp"

# If claude exited non-zero for reasons other than block findings (e.g. crash),
# treat as invocation error.
if [ "$claude_exit" -eq 2 ]; then
  log_stderr "claude CLI returned exit code 2 (invocation error)"
  exit 2
fi

# ---- verify report was written ---------------------------------------------

# Orianna should have written a report. Find the most-recently-written report
# for this plan basename to confirm.
PLAN_BASENAME="$(basename "$PLAN_PATH" .md)"
latest_report=""
# Use [0-9]* to anchor the glob to the ISO timestamp (which always starts with
# a digit). This prevents prefix collisions: e.g. when PLAN_BASENAME is
# "2026-04-19-orianna-fact-checker", the old bare "*.md" glob would also match
# "2026-04-19-orianna-fact-checker-tasks-<timestamp>.md". The [0-9]* anchor
# only matches reports whose suffix begins with a digit, which is true for
# every ISO timestamp (YYYY-…) but not for "-tasks-" or similar variants.
for f in "$REPORT_DIR"/${PLAN_BASENAME}-[0-9]*.md; do
  [ -f "$f" ] && latest_report="$f"
done

if [ -z "$latest_report" ]; then
  log_stderr "WARNING: no report found in $REPORT_DIR for plan $PLAN_BASENAME"
  log_stderr "  claude may have exited cleanly but not written the report"
  # Treat as invocation error rather than clean pass.
  exit 2
fi

log_stderr "report: $latest_report"

# Extract block_findings count from the report frontmatter.
block_count=0
if [ -f "$latest_report" ]; then
  block_count=$(awk '/^---/{n++; if(n==2) exit} /^block_findings:/{gsub(/^block_findings:[[:space:]]*/,""); print}' "$latest_report" || echo 0)
  block_count="${block_count:-0}"
fi

log_stderr "block findings: ${block_count}"

if [ "$block_count" -gt 0 ] || [ "$claude_exit" -eq 1 ]; then
  exit 1
fi

exit 0
