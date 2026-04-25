#!/usr/bin/env bats
# TP1.T7 — xfail end-to-end pipeline integration test
#
# guards T.P1.6 acceptance gate from §4:
#   "Duong can click a plan and see stage × agent × token cost rendered correctly
#    for one historical implemented plan."
#
# Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
#
# xfail: skipped if tools/retro/render.mjs is missing (T.P1.6 not yet landed).
# TODO (T.P1.6): implement html-generator.mjs wiring then flip skip.
#
# POSIX-portable: no find -printf, no GNU sed -i '', no readarray.
# Requires: node >= 18, bats, duckdb CLI on PATH.

RETRO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FIXTURES_E2E_DIR="$RETRO_ROOT/fixtures/e2e"
INGEST_PATH="$RETRO_ROOT/ingest.mjs"
RENDER_PATH="$RETRO_ROOT/render.mjs"
QUERIES_DIR="$RETRO_ROOT/queries"
PLAN_ROLLUP_EXPECTED="$QUERIES_DIR/plan-rollup.expected.json"

# ---------------------------------------------------------------------------
# xfail guard — skip entire suite if render.mjs is not yet implemented
# ---------------------------------------------------------------------------
setup_file() {
  if [ ! -f "$RENDER_PATH" ]; then
    skip "xfail: render.mjs not yet implemented (TODO T.P1.6)"
  fi
  if [ ! -f "$INGEST_PATH" ]; then
    skip "xfail: ingest.mjs not yet implemented (TODO T.P1.2)"
  fi
}

# ---------------------------------------------------------------------------
# setup — seed temp dir from fixture tree
# ---------------------------------------------------------------------------
setup() {
  TMP_DIR="$(mktemp -d /tmp/retro-e2e-XXXXXX)"
  export HOME="$TMP_DIR/fake-home"
  export STRAWBERRY_USAGE_CACHE="$TMP_DIR/strawberry-usage-cache"
  export RETRO_GIT_LOG_MOCK="$FIXTURES_E2E_DIR/git-log-e2e.json"

  mkdir -p "$HOME/.claude/projects/strawberry-agents/sess-e2e-parent/subagents"
  mkdir -p "$STRAWBERRY_USAGE_CACHE/subagent-sentinels"
  mkdir -p "$TMP_DIR/dist/data"

  # Copy fixture subagent transcripts
  cp "$FIXTURES_E2E_DIR/subagents/agent-e2e002.jsonl" \
     "$HOME/.claude/projects/strawberry-agents/sess-e2e-parent/subagents/"
  cp "$FIXTURES_E2E_DIR/subagents/agent-e2e002.meta.json" \
     "$HOME/.claude/projects/strawberry-agents/sess-e2e-parent/subagents/"

  # Copy sentinels
  cp "$FIXTURES_E2E_DIR/subagent-sentinels/agent-e2e002" \
     "$STRAWBERRY_USAGE_CACHE/subagent-sentinels/"

  EVENTS_PATH="$STRAWBERRY_USAGE_CACHE/events.jsonl"
  DIST_DIR="$TMP_DIR/dist"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Test: ingest creates events.jsonl
# ---------------------------------------------------------------------------
@test "retro:ingest produces events.jsonl" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  [ -f "$EVENTS_PATH" ]
}

# ---------------------------------------------------------------------------
# Test: events.jsonl line count matches expected
# ---------------------------------------------------------------------------
@test "events.jsonl has the expected line count for e2e fixture corpus" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  line_count="$(wc -l < "$EVENTS_PATH" | tr -d ' ')"
  # e2e fixture: 1 subagent turn + 2 plan-stage events (from git-log-e2e.json) + 1 dispatch = 4+ lines
  [ "$line_count" -ge 4 ]
}

# ---------------------------------------------------------------------------
# Test: last line of events.jsonl is valid JSON
# ---------------------------------------------------------------------------
@test "last line of events.jsonl is valid JSON" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  last_line="$(tail -1 "$EVENTS_PATH")"
  echo "$last_line" | node -e "process.stdin.resume(); process.stdin.setEncoding('utf8'); let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{ try{JSON.parse(d);process.exit(0);}catch(e){process.exit(1);} })"
}

# ---------------------------------------------------------------------------
# Test: render produces plan-rollup.json matching expected
# ---------------------------------------------------------------------------
@test "retro:render produces dist/data/plan-rollup.json" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR/data"
  [ -f "$DIST_DIR/data/plan-rollup.json" ]
}

# ---------------------------------------------------------------------------
# Test: index.html exists and contains plan anchors
# ---------------------------------------------------------------------------
@test "dist/index.html exists after render" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR"
  [ -f "$DIST_DIR/index.html" ]
}

@test "index.html contains an anchor to the fixture plan slug" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR"
  grep -q 'href="plan-2026-04-21-agent-feedback-system.html"' "$DIST_DIR/index.html"
}

# ---------------------------------------------------------------------------
# Test: plan-detail HTML exists and contains stage x agent x token cells
# ---------------------------------------------------------------------------
@test "plan-2026-04-21-agent-feedback-system.html exists after render" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR"
  [ -f "$DIST_DIR/plan-2026-04-21-agent-feedback-system.html" ]
}

@test "plan-detail HTML contains the 'implemented' stage" {
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR"
  grep -q "implemented" "$DIST_DIR/plan-2026-04-21-agent-feedback-system.html"
}

# ---------------------------------------------------------------------------
# Test: end-to-end wall time on fixture corpus < 5s
# ---------------------------------------------------------------------------
@test "end-to-end pipeline (ingest + render) completes in under 5 seconds on fixture corpus" {
  start_ts="$(date +%s)"
  node "$INGEST_PATH" --cache-dir "$STRAWBERRY_USAGE_CACHE"
  node "$RENDER_PATH" \
    --events "$EVENTS_PATH" \
    --queries-dir "$QUERIES_DIR" \
    --out-dir "$DIST_DIR"
  end_ts="$(date +%s)"
  elapsed="$((end_ts - start_ts))"
  [ "$elapsed" -lt 5 ]
}
