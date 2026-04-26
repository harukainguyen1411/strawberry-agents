#!/usr/bin/env bats
# tests/architecture/test-process-doc-shape.bats
#
# xfail — T2 from plans/approved/personal/2026-04-25-unified-process-synthesis.md
#
# Asserts:
#   1. architecture/agent-network-v1/process.md exists
#   2. The §-numbered headings declared in synthesis §10 are present
#   3. The mermaid block from synthesis §3 is present (sentinel line check)
#
# These tests are expected to FAIL until the doc is authored (xfail-first, Rule 12).
#
# bats test_tags=tag:unified-process-synthesis,tag:xfail

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
DOC="$REPO_ROOT/architecture/agent-network-v1/process.md"

@test "process.md exists" {
  [ -f "$DOC" ]
}

@test "process.md contains Overview section" {
  grep -qF '## Overview' "$DOC"
}

@test "process.md contains Stage 0 heading" {
  grep -qE '^## Stage 0' "$DOC"
}

@test "process.md contains Stage 1 heading" {
  grep -qE '^## Stage 1' "$DOC"
}

@test "process.md contains Stage 2 heading" {
  grep -qE '^## Stage 2' "$DOC"
}

@test "process.md contains Stage 3 heading" {
  grep -qE '^## Stage 3' "$DOC"
}

@test "process.md contains Stage 4 heading" {
  grep -qE '^## Stage 4' "$DOC"
}

@test "process.md contains Stage 5 heading" {
  grep -qE '^## Stage 5' "$DOC"
}

@test "process.md contains Stage 6 heading" {
  grep -qE '^## Stage 6' "$DOC"
}

@test "process.md contains Stage 7 heading" {
  grep -qE '^## Stage 7' "$DOC"
}

@test "process.md contains Stage 8 heading" {
  grep -qE '^## Stage 8' "$DOC"
}

@test "process.md contains Stage 9 heading" {
  grep -qE '^## Stage 9' "$DOC"
}

@test "process.md contains Speed leverage section" {
  grep -qF '## Speed leverage' "$DOC"
}

@test "process.md contains Quality non-negotiables section" {
  grep -qF '## Quality non-negotiables' "$DOC"
}

@test "process.md contains Cross-references section" {
  grep -qF '## Cross-references' "$DOC"
}

@test "process.md contains mermaid block" {
  grep -qF '```mermaid' "$DOC"
}

@test "process.md mermaid block contains IDEA node sentinel" {
  grep -qF 'IDEA' "$DOC"
}

@test "process.md mermaid block contains PROPOSED PLAN node sentinel" {
  grep -qF 'PROPOSED PLAN' "$DOC"
}

@test "process.md mermaid block contains APPROVED PLAN node sentinel" {
  grep -qF 'APPROVED PLAN' "$DOC"
}

@test "process.md mermaid block contains STAGE-2 parallel observers sentinel" {
  grep -qF 'STAGE-2' "$DOC"
}
