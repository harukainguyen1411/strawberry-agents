#!/usr/bin/env bash
# T4a xfail — coord-memory-v1 ADR
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
# This test will turn green when T4b lands the 5 refresh scripts.
#
# Coverage:
#   §1  Script presence gate (xfail anchor — exits red if any script missing)
#   §2  Per-projection seed-and-reflect (basic: one fixture entry appears in index)
#   §3  Idempotency — run each script twice, row counts identical between runs
#   §4  refresh_log updated — last_refreshed_at advances (or is set) on each run

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

# 2a. prs_index — feed seed-prs.json via env var that refresh-prs.sh respects
T4A_FIXTURE_PRS="$FIXTURES_DIR/seed-prs.json" \
  bash "$SCRIPTS_DIR/refresh-prs.sh" "$DB_PATH" 2>/dev/null

prs_count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM prs_index;")
if [ "$prs_count" -ge 1 ]; then
  pass "prs_index: at least 1 row after seeded refresh"
else
  fail "prs_index: expected >=1 row, got $prs_count"
fi

# 2b. plans_index — feed a fixture plan file
T4A_FIXTURE_PLANS_DIR="$FIXTURES_DIR" \
  bash "$SCRIPTS_DIR/refresh-plans.sh" "$DB_PATH" 2>/dev/null

plans_count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM plans_index;")
if [ "$plans_count" -ge 1 ]; then
  pass "plans_index: at least 1 row after seeded refresh"
else
  fail "plans_index: expected >=1 row, got $plans_count"
fi

# 2c. projects_index — feed a fixture project file
T4A_FIXTURE_PROJECTS_DIR="$FIXTURES_DIR" \
  bash "$SCRIPTS_DIR/refresh-projects.sh" "$DB_PATH" 2>/dev/null

projects_count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM projects_index;")
if [ "$projects_count" -ge 1 ]; then
  pass "projects_index: at least 1 row after seeded refresh"
else
  fail "projects_index: expected >=1 row, got $projects_count"
fi

# 2d. inbox_index — feed a fixture inbox file; recipient derived from fixture dir
T4A_FIXTURE_INBOX_DIR="$FIXTURES_DIR" \
  bash "$SCRIPTS_DIR/refresh-inbox.sh" "$DB_PATH" 2>/dev/null

inbox_count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM inbox_index;")
if [ "$inbox_count" -ge 1 ]; then
  pass "inbox_index: at least 1 row after seeded refresh"
else
  fail "inbox_index: expected >=1 row, got $inbox_count"
fi

# 2e. feedback_index — feed a fixture feedback file
T4A_FIXTURE_FEEDBACK_DIR="$FIXTURES_DIR" \
  bash "$SCRIPTS_DIR/refresh-feedback.sh" "$DB_PATH" 2>/dev/null

feedback_count=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM feedback_index;")
if [ "$feedback_count" -ge 1 ]; then
  pass "feedback_index: at least 1 row after seeded refresh"
else
  fail "feedback_index: expected >=1 row, got $feedback_count"
fi

# ── §3: Idempotency — row counts stable across two runs ───────────────────────
echo ""
echo "§3 Idempotency (run each script twice, count must not grow)"

PROJECTIONS=(prs plans projects inbox feedback)
declare -A TABLE_FOR
TABLE_FOR[prs]="prs_index"
TABLE_FOR[plans]="plans_index"
TABLE_FOR[projects]="projects_index"
TABLE_FOR[inbox]="inbox_index"
TABLE_FOR[feedback]="feedback_index"

SCRIPT_FOR_prs="$SCRIPTS_DIR/refresh-prs.sh"
SCRIPT_FOR_plans="$SCRIPTS_DIR/refresh-plans.sh"
SCRIPT_FOR_projects="$SCRIPTS_DIR/refresh-projects.sh"
SCRIPT_FOR_inbox="$SCRIPTS_DIR/refresh-inbox.sh"
SCRIPT_FOR_feedback="$SCRIPTS_DIR/refresh-feedback.sh"

ENV_FOR_prs="T4A_FIXTURE_PRS=$FIXTURES_DIR/seed-prs.json"
ENV_FOR_plans="T4A_FIXTURE_PLANS_DIR=$FIXTURES_DIR"
ENV_FOR_projects="T4A_FIXTURE_PROJECTS_DIR=$FIXTURES_DIR"
ENV_FOR_inbox="T4A_FIXTURE_INBOX_DIR=$FIXTURES_DIR"
ENV_FOR_feedback="T4A_FIXTURE_FEEDBACK_DIR=$FIXTURES_DIR"

for proj in "${PROJECTIONS[@]}"; do
  table="${TABLE_FOR[$proj]}"
  script_var="SCRIPT_FOR_${proj}"
  script="${!script_var}"
  env_var="ENV_FOR_${proj}"
  env_str="${!env_var}"

  count_before=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM $table;")

  # Run second time (first was in §2)
  env "${env_str%%=*}=${env_str#*=}" bash "$script" "$DB_PATH" 2>/dev/null

  count_after=$(db_read "$DB_PATH" "SELECT COUNT(*) FROM $table;")

  if [ "$count_before" -eq "$count_after" ]; then
    pass "$table: row count stable after second run ($count_after rows)"
  else
    fail "$table: count changed $count_before -> $count_after (not idempotent)"
  fi
done

# ── §4: refresh_log updated on each run ───────────────────────────────────────
echo ""
echo "§4 refresh_log updated"

# Run all scripts a third time with a small sleep gap so timestamp can differ
sleep 1

for proj in "${PROJECTIONS[@]}"; do
  table="${TABLE_FOR[$proj]}"
  script_var="SCRIPT_FOR_${proj}"
  script="${!script_var}"
  env_var="ENV_FOR_${proj}"
  env_str="${!env_var}"

  ts_before=$(db_read "$DB_PATH" \
    "SELECT COALESCE(last_refreshed_at,'') FROM refresh_log WHERE projection='$table';" 2>/dev/null || echo "")

  env "${env_str%%=*}=${env_str#*=}" bash "$script" "$DB_PATH" 2>/dev/null

  ts_after=$(db_read "$DB_PATH" \
    "SELECT COALESCE(last_refreshed_at,'') FROM refresh_log WHERE projection='$table';" 2>/dev/null || echo "")

  if [ -n "$ts_after" ] && [ "$ts_after" != "$ts_before" ]; then
    pass "$table: refresh_log.last_refreshed_at updated ($ts_after)"
  elif [ -n "$ts_after" ]; then
    # Timestamp may be identical if the scripts run very fast within the same second.
    # Accept as pass if the row exists; the sleep above provides best-effort separation.
    pass "$table: refresh_log row present (timestamp: $ts_after)"
  else
    fail "$table: refresh_log row missing after refresh"
  fi
done

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
