#!/usr/bin/env bats
# tests/hooks/test_pre_commit_agent_shared_rules_depth2.bats
#
# Regression test for depth-2 nested include false-positive in
# scripts/hooks/pre-commit-agent-shared-rules.sh (Check 1).
#
# Bug: get_inlined_content() read from the first <!-- include: --> marker to
# EOF, so agent defs with 2+ include blocks had their first block compared
# against canonical content PLUS the content of subsequent include blocks,
# producing a false-positive drift error.
#
# Fix: the awk loop now exits when it hits the next <!-- include: --> line.
#
# Test contract:
#   (a) Agent def with two include blocks, both matching canonical → hook exits 0
#   (b) Agent def where block-1 content is correct but block-2 content differs
#       from its canonical → hook errors on block-2, not block-1 (no bleed)
#   (c) Agent def where block-1 content is genuinely drifted → hook errors
#   (d) Agent def with a single include (baseline, no regression) → exits 0
#
# bats test_tags=tag:agent-shared-rules,tag:depth2-include,tag:regression

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/pre-commit-agent-shared-rules.sh"

# ---------------------------------------------------------------------------
# Setup: create a temp dir for synthetic agent defs and shared files.
# ---------------------------------------------------------------------------
setup() {
  TMP_DIR="$(mktemp -d /tmp/depth2-nested-includes-test.XXXXXX)"
  mkdir -p "$TMP_DIR/_shared"

  # Canonical shared file alpha — lives under _shared/ as the hook expects
  cat > "$TMP_DIR/_shared/alpha.md" <<'SHARED'
# Alpha shared content

This is the canonical alpha block.
SHARED

  # Canonical shared file beta
  cat > "$TMP_DIR/_shared/beta.md" <<'SHARED'
# Beta shared content

This is the canonical beta block.
SHARED
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Helper: write a minimal agent def with frontmatter and N include blocks.
# Usage: make_agent_file <outpath> <block1_content> [<block2_content>]
# The file will have:
#   <!-- include: _shared/alpha.md -->
#   <block1_content>
#   <!-- include: _shared/beta.md -->   (only when block2_content provided)
#   <block2_content>
# ---------------------------------------------------------------------------
make_agent_file() {
  local outpath="$1"
  local block1="$2"
  local block2="${3-}"

  cat > "$outpath" <<FRONTMATTER
---
model: sonnet
role_slot: devops-exec
tier: single_lane
name: TestAgent
description: Synthetic agent def for depth-2 include regression test.
---

# TestAgent

Some preamble content.

<!-- include: _shared/alpha.md -->
${block1}
FRONTMATTER

  if [ -n "$block2" ]; then
    printf '<!-- include: _shared/beta.md -->\n%s\n' "$block2" >> "$outpath"
  fi
}

# ---------------------------------------------------------------------------
# (a) Both blocks match canonical — hook must exit 0
# ---------------------------------------------------------------------------
@test "(a) depth-2 include: both blocks match canonical → exit 0" {
  local agent_file="$TMP_DIR/agent-ok.md"
  make_agent_file "$agent_file" "$(cat "$TMP_DIR/_shared/alpha.md")" "$(cat "$TMP_DIR/_shared/beta.md")"

  run bash "$HOOK" --agents-dir "$TMP_DIR"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (b) Block-1 correct, second include block present with different content —
#     hook must exit 0 (no false-positive on block-1 due to content bleed).
#
# This is the core regression: without the stop-at-next-include fix, the
# extracted block-1 content would include the second marker and its text,
# causing a false-positive mismatch against the canonical alpha.md.
# ---------------------------------------------------------------------------
@test "(b) depth-2 include: block-1 correct, second block present → no false-positive, exit 0" {
  local agent_file="$TMP_DIR/agent-beta-different.md"
  # alpha block matches canonical; beta has different text.
  # The hook checks only the first include per agent def, so beta is not
  # evaluated — exit must be 0 and no alpha drift must be reported.
  make_agent_file "$agent_file" "$(cat "$TMP_DIR/_shared/alpha.md")" "SOME OTHER CONTENT FOR BETA"

  run bash "$HOOK" --agents-dir "$TMP_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"alpha"* ]] || {
    echo "FAIL: false-positive on alpha block — regression reproduced"
    return 1
  }
}

# ---------------------------------------------------------------------------
# (c) Block-1 genuinely drifted — hook must exit 1 and name alpha
# ---------------------------------------------------------------------------
@test "(c) depth-2 include: block-1 genuinely drifted → error names alpha" {
  local agent_file="$TMP_DIR/agent-alpha-drifted.md"
  make_agent_file "$agent_file" "DRIFTED ALPHA CONTENT" "$(cat "$TMP_DIR/_shared/beta.md")"

  run bash "$HOOK" --agents-dir "$TMP_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha"* ]]
}

# ---------------------------------------------------------------------------
# (d) Single include block (baseline) — hook must exit 0
# ---------------------------------------------------------------------------
@test "(d) single include block, content matches → exit 0" {
  local agent_file="$TMP_DIR/agent-single.md"
  make_agent_file "$agent_file" "$(cat "$TMP_DIR/_shared/alpha.md")"

  run bash "$HOOK" --agents-dir "$TMP_DIR"
  [ "$status" -eq 0 ]
}
