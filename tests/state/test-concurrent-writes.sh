#!/usr/bin/env bash
# T3a xfail — coord-memory-v1 ADR (complex track, Rakan)
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §D6 §T3a
#
# D6 concurrency invariants under test:
#   - WAL mode allows concurrent readers; BEGIN IMMEDIATE serialises writers
#   - busy_timeout=5000 means no writer gets a hard SQLITE_BUSY failure under
#     normal concurrency pressure (two parallel sessions, O(100) writes each)
#   - All 200 rows committed; none silently dropped
#
# This test is expected RED until T3b lands _lib_db.sh.
# It turns green when Viktor implements the helper library.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"
MIGRATION="$REPO_ROOT/agents/_state/migrations/0001-init.sql"

# ── xfail anchor ─────────────────────────────────────────────────────────────
if [ ! -f "$LIB_DB" ]; then
  echo "XFAIL: _lib_db.sh not present at $LIB_DB"
  echo "This test is expected RED until T3b lands the helper library."
  exit 1
fi

if [ ! -f "$MIGRATION" ]; then
  echo "XFAIL: migration file not present at $MIGRATION"
  echo "This test is expected RED until T2b lands 0001-init.sql."
  exit 1
fi

# shellcheck source=/dev/null
. "$LIB_DB"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

DB_DIR=$(mktemp -d /tmp/test-concurrent-writes-XXXXXX)
DB_PATH="$DB_DIR/state.db"
RESULTS_DIR="$DB_DIR/results"
mkdir -p "$RESULTS_DIR"

cleanup() { rm -rf "$DB_DIR"; }
trap cleanup EXIT

echo "=== T3a: concurrent writes xfail test ==="
echo ""

# ── §1: Seed schema ──────────────────────────────────────────────────────────
echo "§1 Seed schema"
db_open "$DB_PATH"
sqlite3 "$DB_PATH" < "$MIGRATION"
pass "schema seeded"

# ── §2: Fork two writer processes ────────────────────────────────────────────
echo ""
echo "§2 Fork two concurrent writer processes (100 INSERTs each)"

# Writer function: 100 inserts via _lib_db.sh write transaction wrapper.
# Writes result (pass/fail count) to a result file.
run_writer() {
  local writer_id="$1"
  local db="$2"
  local result_file="$3"

  local local_pass=0
  local local_fail=0
  local i
  for i in $(seq 1 100); do
    local slug="writer${writer_id}-decision-${i}"
    local sql="INSERT INTO decisions (coordinator, decided_at, slug, shard_path, summary)
               VALUES ('evelynn', datetime('now'), '${slug}', 'tests/fixture/${slug}.md', 'test decision ${i} from writer ${writer_id}');"
    if db_write_tx "$db" "$sql" 2>/dev/null; then
      local_pass=$((local_pass + 1))
    else
      local_fail=$((local_fail + 1))
    fi
  done
  echo "${local_pass} ${local_fail}" > "$result_file"
}

# Export function and lib so subshells can use them.
export -f run_writer
export -f db_open
export -f db_write_tx

RESULT_A="$RESULTS_DIR/writer_a.txt"
RESULT_B="$RESULTS_DIR/writer_b.txt"

run_writer "A" "$DB_PATH" "$RESULT_A" &
PID_A=$!
run_writer "B" "$DB_PATH" "$RESULT_B" &
PID_B=$!

# Capture exit codes without letting set -e abort on a non-zero child exit.
# `wait $PID || EXITCODE=$?` is the POSIX-safe idiom; bare `wait $PID; EXITCODE=$?`
# would work but `set -e` aborts before $? is captured when the child exits non-zero.
EXITCODE_A=0; wait "$PID_A" || EXITCODE_A=$?
EXITCODE_B=0; wait "$PID_B" || EXITCODE_B=$?

# ── §3: Assert both writers exited cleanly ───────────────────────────────────
echo ""
echo "§3 Assert writer processes exited cleanly"

if [ "$EXITCODE_A" -eq 0 ]; then
  pass "writer A process exited 0"
else
  fail "writer A process exited $EXITCODE_A (unexpected crash)"
fi

if [ "$EXITCODE_B" -eq 0 ]; then
  pass "writer B process exited 0"
else
  fail "writer B process exited $EXITCODE_B (unexpected crash)"
fi

# ── §4: Assert per-writer pass/fail counts ──────────────────────────────────
echo ""
echo "§4 Assert per-writer result counts"

read -r PASS_A FAIL_A < "$RESULT_A"
read -r PASS_B FAIL_B < "$RESULT_B"

if [ "$PASS_A" -eq 100 ]; then
  pass "writer A: all 100 inserts succeeded"
else
  fail "writer A: $PASS_A/100 succeeded, $FAIL_A hard failures (SQLITE_BUSY exhausted)"
fi

if [ "$PASS_B" -eq 100 ]; then
  pass "writer B: all 100 inserts succeeded"
else
  fail "writer B: $PASS_B/100 succeeded, $FAIL_B hard failures (SQLITE_BUSY exhausted)"
fi

# ── §5: Assert total row count in DB ────────────────────────────────────────
echo ""
echo "§5 Assert 200 rows committed"

TOTAL_ROWS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM decisions;")
if [ "$TOTAL_ROWS" -eq 200 ]; then
  pass "200 rows present in decisions table"
else
  fail "expected 200 rows, got $TOTAL_ROWS (rows lost or duplicated)"
fi

# ── §6: Assert zero hard SQLITE_BUSY failures ────────────────────────────────
echo ""
echo "§6 Assert zero hard SQLITE_BUSY failures (D6 invariant)"

TOTAL_FAIL=$((FAIL_A + FAIL_B))
if [ "$TOTAL_FAIL" -eq 0 ]; then
  pass "zero hard SQLITE_BUSY failures across both writers"
else
  fail "$TOTAL_FAIL hard SQLITE_BUSY failure(s) — D6 busy_timeout=5000 + 3-retry invariant violated"
fi

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
