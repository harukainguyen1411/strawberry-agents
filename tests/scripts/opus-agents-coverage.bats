#!/usr/bin/env bats
# tests/scripts/opus-agents-coverage.bats
#
# Regression test: every agent def with `model: opus` must appear in OPUS_AGENTS
# in scripts/lint-subagent-rules.sh, or be explicitly exempted.
#
# Bug: PR #91 found that karma, xayah, senna, lucian, evelynn, sona, orianna were
# missing from OPUS_AGENTS, causing the lint script to apply the SONNET-EXECUTOR
# block to planner/reviewer/coordinator/gatekeeper agents.
#
# Plan ref: plans/approved/personal/2026-04-26-monitor-arming-gate-bugfixes.md

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
LINT_SCRIPT="$REPO_ROOT/scripts/lint-subagent-rules.sh"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

@test "lint-subagent-rules.sh exists" {
  [ -f "$LINT_SCRIPT" ]
}

@test "every model:opus agent is listed in OPUS_AGENTS" {
  # Extract OPUS_AGENTS value from the lint script
  opus_agents_line="$(grep '^OPUS_AGENTS=' "$LINT_SCRIPT")"
  # Strip OPUS_AGENTS=" prefix and trailing "
  opus_agents_value="${opus_agents_line#OPUS_AGENTS=\"}"
  opus_agents_value="${opus_agents_value%\"}"

  # Find all agent defs declaring model: opus
  missing=""
  for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file" .md)"
    if grep -q '^model: opus' "$agent_file"; then
      # Check if this agent appears in the OPUS_AGENTS list
      found=0
      for listed_agent in $opus_agents_value; do
        if [ "$listed_agent" = "$agent_name" ]; then
          found=1
          break
        fi
      done
      if [ "$found" -eq 0 ]; then
        missing="$missing $agent_name"
      fi
    fi
  done

  if [ -n "$missing" ]; then
    echo "Opus agents missing from OPUS_AGENTS in lint-subagent-rules.sh:$missing" >&2
    echo "Add them to OPUS_AGENTS so their defs get the OPUS-PLANNER block, not SONNET-EXECUTOR." >&2
    return 1
  fi
}

@test "no model:sonnet agent is mis-listed in OPUS_AGENTS" {
  # Inverse check: nothing in OPUS_AGENTS should declare model: sonnet
  opus_agents_line="$(grep '^OPUS_AGENTS=' "$LINT_SCRIPT")"
  opus_agents_value="${opus_agents_line#OPUS_AGENTS=\"}"
  opus_agents_value="${opus_agents_value%\"}"

  wrong=""
  for listed_agent in $opus_agents_value; do
    agent_file="$AGENTS_DIR/$listed_agent.md"
    if [ -f "$agent_file" ]; then
      if grep -q '^model: sonnet' "$agent_file"; then
        wrong="$wrong $listed_agent"
      fi
    fi
  done

  if [ -n "$wrong" ]; then
    echo "Sonnet agents mis-listed in OPUS_AGENTS:$wrong" >&2
    return 1
  fi
}

@test "lint script reports 0 drift across all agent defs" {
  run bash "$LINT_SCRIPT"
  [ "$status" -eq 0 ]
}
