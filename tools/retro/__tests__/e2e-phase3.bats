#!/usr/bin/env bats
# TP3.T6 — xfail e2e bats smoke: full Phase-3 acceptance
#
# guards T.P3.4 acceptance gate + Phase-3 regression invariant:
#   - dashboard surfaces lock manifest, bypass log, retro freshness, and (gated) quality grades
#   - Phase-1 and Phase-2 outputs are byte-identical to previous-phase baselines
#
# Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
#
# xfail: skipped if T.P3.4 not yet landed (render.mjs lacks Phase-3 acceptance features).
# TODO (T.P3.4): implement lock-week-active badge + full Phase-3 acceptance features, then flip skip.
#
# DoD checks:
#   (c) dist/index.html snapshot matches Phase-3 acceptance snapshot (lock tile + badge + bypass + no stale + no grade tile)
#   (d) RETRO_QUALITY_GRADE=1 with mock endpoint adds grade tile
#   (e) Phase-1 plan HTML and Phase-2 coordinator HTML are byte-identical to baselines (regression)
#   (f) lock-violation-present class renders when lock-violation events exist
#   (g) total wall time <10s
#
# POSIX-portable. Requires: node >= 18, bats, duckdb CLI on PATH.

RETRO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FIXTURES_DIR="$RETRO_ROOT/fixtures/e2e-phase3"
QUERIES_DIR="$RETRO_ROOT/queries"
INGEST_PATH="$RETRO_ROOT/ingest.mjs"
RENDER_PATH="$RETRO_ROOT/render.mjs"
GRADER_PATH="$RETRO_ROOT/lib/quality-grader.mjs"
SNAPSHOTS_DIR="$RETRO_ROOT/__tests__/__snapshots__"

# Phase-2 regression baseline
PHASE2_BASELINE_DIR="$RETRO_ROOT/fixtures/e2e-phase3/phase2-baseline"

# ---------------------------------------------------------------------------
# xfail guard — skip if render.mjs Phase-3 features not yet implemented
# ---------------------------------------------------------------------------
setup_file() {
  if [ ! -f "$RENDER_PATH" ]; then
    skip "xfail: render.mjs not yet implemented (TODO T.P1.6 / T.P3.4)"
  fi
  if [ ! -f "$INGEST_PATH" ]; then
    skip "xfail: ingest.mjs not yet implemented (TODO T.P1.2)"
  fi
  # Phase-3 acceptance requires the lock-tile (T.P3.2) and lock-bypass scanner (T.P3.1)
  if [ ! -f "$RETRO_ROOT/lib/lock-bypass.mjs" ]; then
    skip "xfail: lib/lock-bypass.mjs not yet implemented (TODO T.P3.1)"
  fi
}

# ---------------------------------------------------------------------------
# setup — seed Phase-3 fixture HOME
# Phase-2 corpus + canonical-v1.md + 3-day-old retro + clean bypass log (2 reconciled entries)
# ---------------------------------------------------------------------------
setup() {
  TMP_DIR="$(mktemp -d /tmp/retro-e2e-p3-XXXXXX)"
  export HOME="$TMP_DIR/fake-home"
  export STRAWBERRY_USAGE_CACHE="$TMP_DIR/strawberry-usage-cache"
  export RETRO_GIT_LOG_MOCK="$FIXTURES_DIR/git-log-e2e-phase3.json"
  export RETRO_RENDER_NOW="2026-04-26T09:00:00.000Z"
  export RETRO_LOCK_TAG_DATE="2026-04-21T00:00:00.000Z"
  export RETRO_LOCK_WEEK_START="2026-04-21"

  # Seed Phase-2 corpus (parent session + subagents + sentinels + feedback + decisions)
  SESS_DIR="$HOME/.claude/projects/strawberry-agents/sess-e2e-parent/subagents"
  mkdir -p "$SESS_DIR"
  mkdir -p "$STRAWBERRY_USAGE_CACHE/subagent-sentinels"

  for f in parent-session-with-prompts.jsonl; do
    [ -f "$FIXTURES_DIR/$f" ] && cp "$FIXTURES_DIR/$f" \
      "$HOME/.claude/projects/strawberry-agents/sess-e2e-parent/sess-e2e-parent.jsonl"
  done
  for f in "$FIXTURES_DIR/subagents/"*.jsonl "$FIXTURES_DIR/subagents/"*.meta.json; do
    [ -f "$f" ] && cp "$f" "$SESS_DIR/"
  done
  for f in "$FIXTURES_DIR/subagent-sentinels/"*; do
    [ -f "$f" ] && cp "$f" "$STRAWBERRY_USAGE_CACHE/subagent-sentinels/"
  done

  FEEDBACK_DIR="$TMP_DIR/strawberry-app/feedback"
  mkdir -p "$FEEDBACK_DIR"
  [ -f "$FIXTURES_DIR/feedback-index.md" ] && cp "$FIXTURES_DIR/feedback-index.md" "$FEEDBACK_DIR/INDEX.md"

  DECISIONS_DIR="$TMP_DIR/strawberry-agents/agents/evelynn/memory/decisions"
  mkdir -p "$DECISIONS_DIR"
  for f in "$FIXTURES_DIR/decisions/evelynn/"*.md; do
    [ -f "$f" ] && cp "$f" "$DECISIONS_DIR/"
  done

  # Phase-3 specific: canonical-v1.md manifest
  ARCH_DIR="$TMP_DIR/strawberry-agents/architecture"
  mkdir -p "$ARCH_DIR"
  cp "$RETRO_ROOT/fixtures/canonical-v1-manifest.md" "$ARCH_DIR/canonical-v1.md"
  export RETRO_ARCHITECTURE_DIR="$ARCH_DIR"

  # 3-day-old retro ADR (fresh, no stale banner)
  PLANS_DIR="$TMP_DIR/strawberry-agents/plans/implemented/personal"
  mkdir -p "$PLANS_DIR"
  [ -f "$FIXTURES_DIR/canonical-v2-rationale-fresh.md" ] && \
    cp "$FIXTURES_DIR/canonical-v2-rationale-fresh.md" \
      "$PLANS_DIR/2026-04-23-canonical-v2-rationale.md"
  export RETRO_PLANS_DIR="$TMP_DIR/strawberry-agents/plans"

  # Bypass log with 2 clean reconciled entries
  cp "$RETRO_ROOT/fixtures/canonical-v1-bypasses-clean.md" "$ARCH_DIR/canonical-v1-bypasses.md"

  EVENTS_PATH="$STRAWBERRY_USAGE_CACHE/events.jsonl"
  DIST_DIR="$TMP_DIR/dist"
  mkdir -p "$DIST_DIR/data"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Test (c): default-gate snapshot — lock tile, badge, bypass count, NO stale, NO grade tile
# ---------------------------------------------------------------------------
@test "Phase-3 ingest+render produces dist/index.html" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  [ -f "$DIST_DIR/index.html" ]
}

@test "Phase-3 dist/index.html contains the lock tile (canonical-v1 reference)" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  grep -q "canonical-v1" "$DIST_DIR/index.html"
}

@test "Phase-3 dist/index.html has lock-week-active badge (current date in lock week)" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  grep -q "lock-week-active" "$DIST_DIR/index.html"
}

@test "Phase-3 dist/index.html has NO stale banner (retro is 3 days old, within 14-day window)" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  ! grep -q "lock-banner-stale" "$DIST_DIR/index.html"
}

@test "Phase-3 dist/index.html has NO quality-grade tile under default gate-off" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  ! grep -q "quality-grade\|grade-tile" "$DIST_DIR/index.html"
}

@test "Phase-3 dist/index.html snapshot matches Phase-3 acceptance snapshot" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  SNAP="$SNAPSHOTS_DIR/index-phase3-acceptance.html.snap"
  if [ ! -f "$SNAP" ]; then
    echo "Snapshot missing: $SNAP — set UPDATE_SNAPSHOTS=1 and run once to create the golden file."
    return 1
  fi
  diff -q "$DIST_DIR/index.html" "$SNAP" || {
    echo "Phase-3 acceptance snapshot mismatch"
    return 1
  }
}

# ---------------------------------------------------------------------------
# Test (d): RETRO_QUALITY_GRADE=1 with mocked endpoint → grade tile appears
# ---------------------------------------------------------------------------
@test "Phase-3: quality-grade tile appears when RETRO_QUALITY_GRADE=1 with mock endpoint" {
  if [ ! -f "$GRADER_PATH" ]; then
    skip "lib/quality-grader.mjs not yet implemented (TODO T.P3.3)"
  fi
  MOCK_FIXTURE="$RETRO_ROOT/fixtures/anthropic-graded.json"
  if [ ! -f "$MOCK_FIXTURE" ]; then
    skip "anthropic-graded.json fixture not yet created (TODO T.P3.3)"
  fi

  export RETRO_QUALITY_GRADE=1
  export RETRO_ANTHROPIC_MOCK_ENDPOINT="$MOCK_FIXTURE"
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"

  grep -q "quality-grade\|grade-tile" "$DIST_DIR/index.html"
}

# ---------------------------------------------------------------------------
# Test (e): regression invariant — Phase-1 and Phase-2 outputs are byte-identical to baselines
# ---------------------------------------------------------------------------
@test "Phase-1 plan HTML is byte-identical to Phase-2 baseline after Phase-3 render" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"

  p1_slug="2026-04-21-agent-feedback-system"
  p1_actual="$DIST_DIR/plan-${p1_slug}.html"
  p1_baseline="$PHASE2_BASELINE_DIR/plan-${p1_slug}.html"
  [ -f "$p1_actual" ]
  if [ -f "$p1_baseline" ]; then
    diff -q "$p1_actual" "$p1_baseline" || {
      echo "Phase-1 plan HTML changed after Phase-3 render (regression)"
      return 1
    }
  fi
}

@test "Phase-2 coordinator-detail HTML is byte-identical to Phase-2 baseline after Phase-3 render" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"

  p2_actual="$(ls "$DIST_DIR"/coordinator-evelynn-week-*.html 2>/dev/null | head -1)"
  p2_baseline="$(ls "$PHASE2_BASELINE_DIR"/coordinator-evelynn-week-*.html 2>/dev/null | head -1)"
  if [ -n "$p2_actual" ] && [ -n "$p2_baseline" ]; then
    diff -q "$p2_actual" "$p2_baseline" || {
      echo "Phase-2 coordinator HTML changed after Phase-3 render (regression)"
      return 1
    }
  fi
}

# ---------------------------------------------------------------------------
# Test (f): lock-violation-present class renders when lock-violation events exist
# DoD-(f): lock-tile renders violation count with class lock-violation-present
#          and a deep-link to architecture/canonical-v1-bypasses.md
# ---------------------------------------------------------------------------
@test "Phase-3: lock-violation-present class appears when manifest-path commit has no bypass trailer" {
  # Inject a git-log with a missing-trailer manifest-path commit
  cat > "$TMP_DIR/git-log-violation.json" <<'JSON'
[{
  "sha": "violation0001",
  "subject": "chore: edit .claude/agents/evelynn.md without bypass",
  "authorDate": "2026-04-22T10:00:00.000Z",
  "touchedFiles": [".claude/agents/evelynn.md"],
  "trailers": []
}]
JSON
  export RETRO_GIT_LOG_MOCK="$TMP_DIR/git-log-violation.json"

  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"

  grep -q "lock-violation-present" "$DIST_DIR/index.html"
}

@test "Phase-3: lock-violation tile has deep-link to canonical-v1-bypasses.md" {
  cat > "$TMP_DIR/git-log-violation.json" <<'JSON'
[{
  "sha": "violation0002",
  "subject": "chore: edit CLAUDE.md without bypass",
  "authorDate": "2026-04-23T10:00:00.000Z",
  "touchedFiles": ["CLAUDE.md"],
  "trailers": []
}]
JSON
  export RETRO_GIT_LOG_MOCK="$TMP_DIR/git-log-violation.json"

  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"

  grep -q "canonical-v1-bypasses" "$DIST_DIR/index.html"
}

# ---------------------------------------------------------------------------
# Test (g): total wall time <10s
# ---------------------------------------------------------------------------
@test "Phase-3 end-to-end pipeline completes in under 10 seconds on fixture corpus" {
  start_ts="$(date +%s)"
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" --events "$EVENTS_PATH" --queries-dir "$QUERIES_DIR" --out-dir "$DIST_DIR"
  end_ts="$(date +%s)"
  elapsed="$((end_ts - start_ts))"
  [ "$elapsed" -lt 10 ]
}
