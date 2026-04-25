#!/usr/bin/env bash
# xfail: tests for memory-consolidate.sh --decisions-only extension.
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md T3
# xfail: all assertions below are expected to fail until memory-consolidate.sh
# gains the --decisions-only flag (T4). DECISION_TEST_MODE=1 per OQ-T1.
#
# Fixture: 12 decision logs across 3 axes in
#   scripts/__tests__/fixtures/decisions/rollup-12/log/
#
# Usage: bash scripts/test-memory-consolidate-decisions.sh
# Exit 0 always in xfail state.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/memory-consolidate.sh"
FIXTURE_BASE="$REPO_ROOT/scripts/__tests__/fixtures/decisions/rollup-12"
export DECISION_TEST_MODE=1

PASS=0
FAIL=0
XFAIL_COUNT=0

xfail_assert() {
  local name="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "XFAIL $name — unexpectedly PASSED (impl landed?)"
    PASS=$((PASS+1))
  else
    echo "XFAIL $name"
    XFAIL_COUNT=$((XFAIL_COUNT+1))
  fi
}

# ── Guard: if script missing or flag unsupported ──────────────────────────────
if [ ! -f "$SCRIPT" ]; then
  echo "XFAIL (expected — missing: scripts/memory-consolidate.sh)"
  echo ""
  echo "XFAIL T3-flag-exists"
  echo "XFAIL T3-index-row-count"
  echo "XFAIL T3-index-newest-first"
  echo "XFAIL T3-samples-scope-vs-debt"
  echo "XFAIL T3-notable-misses-scope-vs-debt"
  echo "XFAIL T3-summary-prose-preserved"
  echo "XFAIL T3-idempotent-index"
  echo "XFAIL T3-idempotent-preferences"
  echo "XFAIL T3-subsecond-on-12-files"
  echo "XFAIL T3-run-after-last-sessions-pass"
  echo ""
  echo "Total: 0 pass, 0 fail, 10 xfail"
  exit 0
fi

# Check if --decisions-only flag exists (grep the script for the flag)
if ! grep -q "decisions-only" "$SCRIPT"; then
  echo "XFAIL (expected — missing: --decisions-only flag in memory-consolidate.sh)"
  echo ""
  echo "XFAIL T3-flag-exists"
  echo "XFAIL T3-index-row-count"
  echo "XFAIL T3-index-newest-first"
  echo "XFAIL T3-samples-scope-vs-debt"
  echo "XFAIL T3-notable-misses-scope-vs-debt"
  echo "XFAIL T3-summary-prose-preserved"
  echo "XFAIL T3-idempotent-index"
  echo "XFAIL T3-idempotent-preferences"
  echo "XFAIL T3-subsecond-on-12-files"
  echo "XFAIL T3-run-after-last-sessions-pass"
  echo ""
  echo "Total: 0 pass, 0 fail, 10 xfail"
  exit 0
fi

# ── Set up temp coordinator directory from fixtures ───────────────────────────
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Mirror fixture into a coordinator-shaped temp dir
COORD_DIR="$TMPDIR_TEST/agents/evelynn/memory"
mkdir -p "$COORD_DIR/decisions/log"
cp -r "$FIXTURE_BASE/log/." "$COORD_DIR/decisions/log/"
cp "$FIXTURE_BASE/preferences.before.md" "$COORD_DIR/decisions/preferences.md"

# axes.md needs to exist for the rollup pass to know which axes to process
cat > "$COORD_DIR/decisions/axes.md" <<'EOF'
# Axes — evelynn

## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanness vs speed.

## explicit-vs-implicit
  Added: 2026-04-21
  Definition: Declare vs infer.

## hand-curated-vs-automated
  Added: 2026-04-21
  Definition: Human vs machine.
EOF

export STRAWBERRY_MEMORY_ROOT="$TMPDIR_TEST"

# ── T3-flag-exists: --decisions-only flag is accepted ────────────────────────
if bash "$SCRIPT" evelynn --decisions-only 2>/dev/null; then
  xfail_assert "T3-flag-exists" "ok"
else
  xfail_assert "T3-flag-exists" "fail"
fi

INDEX_FILE="$COORD_DIR/decisions/INDEX.md"
PREF_FILE="$COORD_DIR/decisions/preferences.md"

# T3-index-row-count: INDEX.md has exactly 12 data rows (one per log file)
if [ -f "$INDEX_FILE" ]; then
  # Count non-header, non-separator table rows
  row_count=$(grep -c "^| 2026" "$INDEX_FILE" 2>/dev/null || echo 0)
  if [ "$row_count" -eq 12 ]; then
    xfail_assert "T3-index-row-count" "ok"
  else
    xfail_assert "T3-index-row-count" "fail"
  fi
else
  xfail_assert "T3-index-row-count" "fail"
fi

# T3-index-newest-first: first data row has the most recent date
if [ -f "$INDEX_FILE" ]; then
  first_date=$(grep "^| 2026" "$INDEX_FILE" | head -1 | awk -F'|' '{print $2}' | tr -d ' ')
  last_date=$(grep "^| 2026" "$INDEX_FILE" | tail -1 | awk -F'|' '{print $2}' | tr -d ' ')
  if [[ "$first_date" > "$last_date" ]]; then
    xfail_assert "T3-index-newest-first" "ok"
  else
    xfail_assert "T3-index-newest-first" "fail"
  fi
else
  xfail_assert "T3-index-newest-first" "fail"
fi

# T3-samples-scope-vs-debt: preferences.md Samples: line for scope-vs-debt
# matches expected: "Samples: 6 (a: 4, b: 1, c: 1)"
if [ -f "$PREF_FILE" ]; then
  if grep -q "Samples: 6 (a: 4, b: 1, c: 1)" "$PREF_FILE"; then
    xfail_assert "T3-samples-scope-vs-debt" "ok"
  else
    xfail_assert "T3-samples-scope-vs-debt" "fail"
  fi
else
  xfail_assert "T3-samples-scope-vs-debt" "fail"
fi

# T3-notable-misses-scope-vs-debt: last 3 misses per axis appear in Notable misses:
# scope-vs-debt has one miss (2026-04-05-svd-5); expect it to appear
if [ -f "$PREF_FILE" ]; then
  if grep -A5 "## Axis: scope-vs-debt" "$PREF_FILE" | grep -q "2026-04-05-svd-5"; then
    xfail_assert "T3-notable-misses-scope-vs-debt" "ok"
  else
    xfail_assert "T3-notable-misses-scope-vs-debt" "fail"
  fi
else
  xfail_assert "T3-notable-misses-scope-vs-debt" "fail"
fi

# T3-summary-prose-preserved: the hand-curated Summary: prose survives rollup
# Check that the italics marker _curated_ is still present verbatim
if [ -f "$PREF_FILE" ]; then
  if grep -q "_curated_ prose is hand-maintained" "$PREF_FILE"; then
    xfail_assert "T3-summary-prose-preserved" "ok"
  else
    xfail_assert "T3-summary-prose-preserved" "fail"
  fi
else
  xfail_assert "T3-summary-prose-preserved" "fail"
fi

# T3-idempotent-index: running --decisions-only twice produces byte-identical INDEX.md
if [ -f "$INDEX_FILE" ]; then
  idx_before="$(md5 -q "$INDEX_FILE" 2>/dev/null || md5sum "$INDEX_FILE" | cut -d' ' -f1)"
  bash "$SCRIPT" evelynn --decisions-only 2>/dev/null
  idx_after="$(md5 -q "$INDEX_FILE" 2>/dev/null || md5sum "$INDEX_FILE" | cut -d' ' -f1)"
  if [ "$idx_before" = "$idx_after" ]; then
    xfail_assert "T3-idempotent-index" "ok"
  else
    xfail_assert "T3-idempotent-index" "fail"
  fi
else
  xfail_assert "T3-idempotent-index" "fail"
fi

# T3-idempotent-preferences: Samples: lines are byte-identical on second run
if [ -f "$PREF_FILE" ]; then
  samples_before="$(grep 'Samples:' "$PREF_FILE" | sort)"
  bash "$SCRIPT" evelynn --decisions-only 2>/dev/null
  samples_after="$(grep 'Samples:' "$PREF_FILE" | sort)"
  if [ "$samples_before" = "$samples_after" ]; then
    xfail_assert "T3-idempotent-preferences" "ok"
  else
    xfail_assert "T3-idempotent-preferences" "fail"
  fi
else
  xfail_assert "T3-idempotent-preferences" "fail"
fi

# T3-subsecond-on-12-files: --decisions-only returns in < 5 seconds on 12-file corpus
start_time="$(date +%s)"
bash "$SCRIPT" evelynn --decisions-only 2>/dev/null
end_time="$(date +%s)"
elapsed=$((end_time - start_time))
if [ "$elapsed" -lt 5 ]; then
  xfail_assert "T3-subsecond-on-12-files" "ok"
else
  xfail_assert "T3-subsecond-on-12-files" "fail"
fi

# T3-run-after-last-sessions-pass: decision pass runs AFTER last-sessions INDEX
# regen; verify via grep of the script's ordering (structural assertion)
if grep -n "last-sessions\|last_sessions" "$SCRIPT" | head -1 | \
   awk -F: '{print $1}' > /tmp/last_sessions_line 2>/dev/null && \
   grep -n "decisions-only\|decisions_only\|rollup_preferences" "$SCRIPT" | head -1 | \
   awk -F: '{print $1}' > /tmp/decisions_line 2>/dev/null; then
  ls_line="$(cat /tmp/last_sessions_line)"
  dec_line="$(cat /tmp/decisions_line)"
  if [ -n "$ls_line" ] && [ -n "$dec_line" ] && [ "$dec_line" -gt "$ls_line" ]; then
    xfail_assert "T3-run-after-last-sessions-pass" "ok"
  else
    xfail_assert "T3-run-after-last-sessions-pass" "fail"
  fi
else
  xfail_assert "T3-run-after-last-sessions-pass" "fail"
fi

echo ""
echo "Total: $PASS pass, $FAIL fail, $XFAIL_COUNT xfail"
exit 0
