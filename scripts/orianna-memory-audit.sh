#!/bin/sh
# orianna-memory-audit.sh — invoke Orianna in memory-audit mode and commit the report.
#
# Usage: scripts/orianna-memory-audit.sh
#   No arguments. Reads only committed state. Writes to assessments/memory-audits/.
#   Compatible with a future GitHub Actions scheduled workflow (no interactive prompts,
#   exits non-zero only on hard errors).
#
# Exit codes:
#   0  — report written and committed successfully
#   1  — invocation error (claude CLI crashed / timed out / no output)
#   2  — missing prerequisite (claude CLI not found, or strawberry-app checkout absent
#        and cross-repo checks are required)
#
# v2 note: when GitHub Actions automation lands, this script can be called verbatim
# from the workflow step — no changes needed to the invocation shape.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_FILE="$REPO_ROOT/agents/orianna/prompts/memory-audit.md"
REPORT_DIR="$REPO_ROOT/assessments/memory-audits"
ISO_DATE="$(date +%Y-%m-%d)"
REPORT_FILE="$REPORT_DIR/${ISO_DATE}-memory-audit.md"

# ── prerequisite: claude CLI ────────────────────────────────────────────────
if ! command -v claude > /dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH." >&2
  echo "Memory audits require semantic judgment; the mechanical bash fallback" >&2
  echo "is not meaningful across 20+ memory files. Install the claude CLI." >&2
  exit 2
fi

# ── prerequisite: prompt file ───────────────────────────────────────────────
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

# ── prerequisite: report directory ──────────────────────────────────────────
if [ ! -d "$REPORT_DIR" ]; then
  echo "ERROR: report directory not found: $REPORT_DIR" >&2
  echo "Run scripts/install-hooks.sh or create the directory with a .gitkeep." >&2
  exit 2
fi

# ── fetch fresh SHAs for both repos ─────────────────────────────────────────
echo "Fetching origin/main for strawberry repo..."
git -C "$REPO_ROOT" fetch origin main 2>/dev/null || true

STRAWBERRY_SHA="$(git -C "$REPO_ROOT" rev-parse --short origin/main 2>/dev/null || echo "unknown")"

STRAWBERRY_APP_DIR="$HOME/Documents/Personal/strawberry-app"
STRAWBERRY_APP_SHA="checkout-absent"
if [ -d "$STRAWBERRY_APP_DIR/.git" ]; then
  echo "Fetching origin/main for strawberry-app repo..."
  git -C "$STRAWBERRY_APP_DIR" fetch origin main 2>/dev/null || true
  STRAWBERRY_APP_SHA="$(git -C "$STRAWBERRY_APP_DIR" rev-parse --short origin/main 2>/dev/null || echo "unknown")"
else
  echo "WARN: strawberry-app checkout not found at $STRAWBERRY_APP_DIR" >&2
  echo "      Cross-repo claims will be flagged as unverifiable." >&2
fi

# ── build the task prompt ────────────────────────────────────────────────────
TASK_PROMPT="$(cat "$PROMPT_FILE")

Additional context for this run:
- Today's date: $ISO_DATE
- strawberry repo origin/main SHA: $STRAWBERRY_SHA
- strawberry-app origin/main SHA: $STRAWBERRY_APP_SHA
- strawberry-app checkout path: $STRAWBERRY_APP_DIR

Write the report to: $REPORT_FILE"

# ── invoke Orianna ───────────────────────────────────────────────────────────
echo "Invoking Orianna (memory-audit mode)..."
if ! claude -p --agent orianna --dangerously-skip-permissions "$TASK_PROMPT" > /tmp/orianna-memory-audit-output.txt 2>&1; then
  echo "ERROR: claude CLI exited non-zero. Output:" >&2
  cat /tmp/orianna-memory-audit-output.txt >&2
  exit 1
fi

# ── verify report was written ────────────────────────────────────────────────
if [ ! -f "$REPORT_FILE" ]; then
  # Orianna may have written to a slightly different path; search for it
  CANDIDATE="$(ls "$REPORT_DIR"/${ISO_DATE}-*.md 2>/dev/null | tail -1 || true)"
  if [ -z "$CANDIDATE" ]; then
    echo "ERROR: Orianna ran but no report file found under $REPORT_DIR." >&2
    echo "Claude output:" >&2
    cat /tmp/orianna-memory-audit-output.txt >&2
    exit 1
  fi
  REPORT_FILE="$CANDIDATE"
fi

echo "Report written: $REPORT_FILE"

# ── parse summary line from output for display ───────────────────────────────
BLOCK_COUNT="$(grep -m1 '^BLOCK:' /tmp/orianna-memory-audit-output.txt 2>/dev/null | awk '{print $2}' || echo "?")"
WARN_COUNT="$(grep -m1 '^WARN:' /tmp/orianna-memory-audit-output.txt 2>/dev/null | awk '{print $2}' || echo "?")"
INFO_COUNT="$(grep -m1 '^INFO:' /tmp/orianna-memory-audit-output.txt 2>/dev/null | awk '{print $2}' || echo "?")"
echo "Findings — block: $BLOCK_COUNT  warn: $WARN_COUNT  info: $INFO_COUNT"

# ── commit the report ────────────────────────────────────────────────────────
cd "$REPO_ROOT"
git add "$REPORT_FILE"
git commit -m "chore: orianna memory audit $ISO_DATE — block:$BLOCK_COUNT warn:$WARN_COUNT info:$INFO_COUNT"

# ── push ─────────────────────────────────────────────────────────────────────
echo "Pushing..."
git push

echo "Done. Report: $REPORT_FILE"
