#!/usr/bin/env bats
# tests/agents/coordinator-routing-check-wired.bats
#
# T1 — xfail: assert coordinator-routing-check primitive is wired into both
# coordinator defs and that both new artifact files exist with expected content.
#
# Plan: plans/approved/personal/2026-04-25-coordinator-routing-discipline.md T1
#
# bats test_tags=tag:routing-discipline

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"

@test "evelynn.md includes coordinator-routing-check directive" {
  grep -F '<!-- include: _shared/coordinator-routing-check.md -->' \
    "$REPO_ROOT/.claude/agents/evelynn.md"
}

@test "sona.md includes coordinator-routing-check directive" {
  grep -F '<!-- include: _shared/coordinator-routing-check.md -->' \
    "$REPO_ROOT/.claude/agents/sona.md"
}

@test "coordinator-routing-check.md include file exists" {
  [ -f "$REPO_ROOT/.claude/agents/_shared/coordinator-routing-check.md" ]
}

@test "architecture/agent-network-v1/routing.md exists and contains lane lookup table heading" {
  [ -f "$REPO_ROOT/architecture/agent-network-v1/routing.md" ]
  grep -F '## 2. Lane lookup table' "$REPO_ROOT/architecture/agent-network-v1/routing.md"
}
