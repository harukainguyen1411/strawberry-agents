#!/usr/bin/env bash
# T4a xfail — coord-memory-v1 ADR
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
# This test will turn green when T4b lands the 5 refresh scripts.
#
# Coverage:
#   §1    Script presence gate (xfail anchor — exits red if any script missing)
#   §2    Per-projection seed-and-reflect (one fixture entry per index table)
#   §3    Idempotency — row counts stable across two runs per projection
#   §3'   UPSERT semantics — mutated fixture reflects in prs_index on re-run
#   §4    refresh_log updated — sub-second last_refreshed_at advances each run
#
# Fixture layout (per-projection subdirs, consumed via T4A_FIXTURE_* env vars):
#   fixtures/prs/seed-prs.json          → T4A_FIXTURE_PRS
#   fixtures/plans/                     → T4A_FIXTURE_PLANS_DIR
#   fixtures/projects/                  → T4A_FIXTURE_PROJECTS_DIR
#   fixtures/inbox/                     → T4A_FIXTURE_INBOX_DIR
#   fixtures/feedback/                  → T4A_FIXTURE_FEEDBACK_DIR

# shellcheck disable=SC2034  # SCRIPT_FOR_* / ENV_FOR_* used via ${!var} indirection
# shellcheck disable=SC2317  # cleanup() called via trap, not detected by shellcheck

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts/state"
LIB_DB="$SCRIPTS_DIR/_lib_db.sh"
MIGRATIONS_DIR="$REPO_ROOT/agents/_state/migrations"
FIXTURES_DIR="$(dirname "$0")/fixtures"

DB_DIR="/tmp/test-refresh-$$"
DB_PATH="$DB_DIR/state.db"

PASS=0
FAIL=0
MISSING_SCRIPTS=()

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

echo "=== T4a: refresh-script idempotency xfail test ==="
echo ""

# ── §1: Script presence gate ──────────────────────────────────────────────────
echo "§1 Script presence check"

REQUIRED_SCRIPTS=(
  "$SCRIPTS_DIR/refresh-prs.sh"
  "$SCRIPTS_DIR/refresh-plans.sh"
  "$SCRIPTS_DIR/refresh-projects.sh"
  "$SCRIPTS_DIR/refresh-inbox.sh"
  "$SCRIPTS_DIR/refresh-feedback.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    MISSING_SCRIPTS+=("$script")
  fi
done

if [ "${#MISSING_SCRIPTS[@]}" -gt 0 ]; then
  echo "XFAIL: the following refresh scripts are not yet present:"
  for s in "${MISSING_SCRIPTS[@]}"; do
    echo "  missing: $s"
  done
  echo "This test is expected to be red until T4b lands the refresh scripts."
  exit 1
fi

if [ ! -f "$LIB_DB" ]; then
  echo "XFAIL: _lib_db.sh not found: $LIB_DB"
  exit 1
fi

# ── DB setup ──────────────────────────────────────────────────────────────────
mkdir -p "$DB_DIR"
# shellcheck source=/dev/null
. "$LIB_DB"
db_apply_migrations "$DB_PATH" "$MIGRATIONS_DIR"

# ── §2: Per-projection seed-and-reflect ───────────────────────────────────────
echo ""
echo "§2 Per-projection seed-and-reflect"

run_refresh() {
  local proj="$1" db="$2"
  local err rc
  case "$proj" in
    prs)
      err=$(T4A_FIXTURE_PRS="$FIXTURES_DIR/prs/seed-prs.json" \
        bash "$SCRIPTS_DIR/refresh-prs.sh" "$db" 2>&1); rc=$?
      ;;
    plans)
      err=$(T4A_FIXTURE_PLANS_DIR="$FIXTURES_DIR/plans" \
        bash "$SCRIPTS_DIR/refresh-plans.sh" "$db" 2>&1); rc=$?
      ;;
    projects)
      err=$(T4A_FIXTURE_PROJECTS_DIR="$FIXTURES_DIR/projects" \
        bash "$SCRIPTS_DIR/refresh-projects.sh" "$db" 2>&1); rc=$?
      ;;
    inbox)
      err=$(T4A_FIXTURE_INBOX_DIR="$FIXTURES_DIR/inbox" \
        bash "$SCRIPTS_DIR/refresh-inbox.sh" "$db" 2>&1); rc=$?
      ;;
    feedback)
      err=$(T4A_FIXTURE_FEEDBACK_DIR="$FIXTURES_DIR/feedback" \
        bash "$SCRIPTS_DIR/refresh-feedback.sh" "$db" 2>&1); rc=$?
      ;;
    *)
      echo "run_refresh: unknown projection '$proj'" >&2; return 1 ;;
  esac
  if [ "$rc" -ne 0 ]; then
    echo "  [stderr from refresh-${proj}.sh]: $err" >&2
    return "$rc"
  fi
  return 0
}

declare -A TABLE_FOR
TABLE_FOR[prs]="prs_index"
TABLE_FOR[plans]="plans_index"
TABLE_FOR[projects]="projects_index"
TABLE_FOR[inbox]="inbox_index"
TABLE_FOR[feedback]="feedback_index"

PROJECTIONS=(prs plans projects inbox feedback)

for proj in "${PROJECTIONS[@]}"; do
  table="${TABLE_FOR[$proj]}"
  if run_refresh "$proj" "$DB_PATH"; then
    count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM $table;")
    if [ "$count" -ge 1 ]; then
      pass "$table: $count row(s) after seeded refresh"
    else
      fail "$table: expected >=1 row, got $count"
    fi
  else
    fail "$table: refresh-${proj}.sh exited non-zero (see stderr above)"
  fi
done

# ── §3: Idempotency — row counts stable across two runs ───────────────────────
echo ""
echo "§3 Idempotency (second run — count must not grow)"

for proj in "${PROJECTIONS[@]}"; do
  table="${TABLE_FOR[$proj]}"
  count_before=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM $table;")

  if run_refresh "$proj" "$DB_PATH"; then
    count_after=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM $table;")
    if [ "$count_before" -eq "$count_after" ]; then
      pass "$table: count stable ($count_after rows)"
    else
      fail "$table: count changed $count_before -> $count_after (not idempotent)"
    fi
  else
    fail "$table: refresh-${proj}.sh exited non-zero on second run"
  fi
done

# ── §3': UPSERT semantics — mutated fixture reflects on re-run ─────────────────
echo ""
echo "§3' UPSERT semantics (mutation must reflect — not silently ignored)"

# Re-run prs_index with the mutated fixture (PR #101 title changed)
title_before=$(db_read "$DB_PATH" "SELECT title FROM prs_index WHERE number=101;" 2>/dev/null || echo "")

err=$(T4A_FIXTURE_PRS="$FIXTURES_DIR/prs/seed-prs-mutated.json" \
  bash "$SCRIPTS_DIR/refresh-prs.sh" "$DB_PATH" 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  fail "prs_index UPSERT: refresh-prs.sh exited non-zero: $err"
else
  title_after=$(db_read "$DB_PATH" "SELECT title FROM prs_index WHERE number=101;" 2>/dev/null || echo "")
  if [ "$title_after" = "feat: seed PR alpha MUTATED for upsert test" ]; then
    pass "prs_index UPSERT: mutated title reflected (was: '$title_before')"
  else
    fail "prs_index UPSERT: title not updated (got: '$title_after') — INSERT OR IGNORE instead of UPSERT?"
  fi
fi

# ── §4: refresh_log updated on each run ───────────────────────────────────────
echo ""
echo "§4 refresh_log updated (sub-second timestamp)"

# Refresh scripts must write last_refreshed_at using sub-second precision
# (strftime('%Y-%m-%d %H:%M:%f', 'now')) so consecutive runs within the same
# wall-clock second are still distinguishable. No sleep needed.

for proj in "${PROJECTIONS[@]}"; do
  table="${TABLE_FOR[$proj]}"

  ts_before=$(db_read "$DB_PATH" \
    "SELECT COALESCE(last_refreshed_at,'') FROM refresh_log WHERE projection='$table';" 2>/dev/null || echo "")

  if run_refresh "$proj" "$DB_PATH"; then
    ts_after=$(db_read "$DB_PATH" \
      "SELECT COALESCE(last_refreshed_at,'') FROM refresh_log WHERE projection='$table';" 2>/dev/null || echo "")

    if [ -z "$ts_after" ]; then
      fail "$table: refresh_log row missing after refresh"
    elif [ "$ts_after" != "$ts_before" ]; then
      pass "$table: refresh_log.last_refreshed_at updated ($ts_after)"
    else
      fail "$table: refresh_log.last_refreshed_at unchanged ($ts_after) — use sub-second strftime('%Y-%m-%d %H:%M:%f','now')"
    fi
  else
    fail "$table: refresh-${proj}.sh exited non-zero in §4"
  fi
done

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
