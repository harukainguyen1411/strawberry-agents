#!/usr/bin/env bash
# lint-subagent-rules.sh
# Diff the canonical inline rule block from each .claude/agents/*.md against
# reference blocks for Sonnet-executor and Opus-planner agents.
#
# Usage: bash scripts/lint-subagent-rules.sh [--fix]
#   --fix  (not implemented) would auto-update the canonical blocks
#
# Exit codes:
#   0 — all agents clean
#   1 — one or more agents have drift (blocks missing or content differs)
#   2 — usage error
#
# POSIX-portable bash. Runs on macOS and Git Bash on Windows.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

# ---------------------------------------------------------------------------
# Reference blocks — update these when canonical rules change.
# Each block is the text that MUST appear between the BEGIN/END comments
# in every agent of that tier.
# ---------------------------------------------------------------------------

SONNET_REF='- Sonnet executor: execute approved plans only — you never design plans yourself. Every task must reference a plan file in `plans/approved/` or `plans/in-progress/`. If Evelynn invokes you without a plan, ask for one before proceeding. (`#rule-sonnet-needs-plan`)
- All commits use `chore:` or `ops:` prefix. No `fix:`/`feat:`/`docs:`/`plan:`. (`#rule-chore-commit-prefix`)
- Never leave work uncommitted before any git operation that changes the working tree. (`#rule-no-uncommitted-work`)
- Never write secrets into committed files. Use `secrets/` (gitignored) or env vars. (`#rule-no-secrets-in-commits`)
- Never run raw `age -d` — always use `tools/decrypt.sh`. (`#rule-no-raw-age-d`)
- Use `git worktree` for branches. Never raw `git checkout`. Use `scripts/safe-checkout.sh` if available. (`#rule-git-worktree`)
- Implementation work goes through a PR. Plans go directly to main. (`#rule-plans-direct-to-main`)
- Avoid shell approval prompts — no quoted strings with spaces, no $() expansion, no globs in git bash commands.
- Never end your session after completing a task — complete, report to Evelynn, then wait. (`#rule-end-session-skill`)
- Close via `/end-subagent-session` only when Evelynn instructs you to close.'

OPUS_REF='- Opus planner: write plans to `plans/proposed/` and stop — you never self-implement. Your task is done after writing the plan; return a summary to Evelynn. (`#rule-plan-gate`, `#rule-plan-writers-no-assignment`)
- All commits use `chore:` or `ops:` prefix. Plans commit directly to main, never via PR. (`#rule-chore-commit-prefix`, `#rule-plans-direct-to-main`)
- Never leave work uncommitted before any git operation that changes the working tree. (`#rule-no-uncommitted-work`)
- Never write secrets into committed files. Use `secrets/` (gitignored) or env vars. (`#rule-no-secrets-in-commits`)
- Never run raw `age -d` — always use `tools/decrypt.sh`. (`#rule-no-raw-age-d`)
- Do not assign implementers in plans. `owner:` frontmatter is authorship only — Evelynn decides delegation. (`#rule-plan-writers-no-assignment`)
- Close via `/end-subagent-session` only when Evelynn instructs you to close. (`#rule-end-session-skill`)'

# ---------------------------------------------------------------------------
# Agent tier classification.
# Agents with model: opus => planner tier. Others => sonnet executor tier.
# Poppy (haiku) is a special case — it has no canonical rule block (scope too narrow).
# ---------------------------------------------------------------------------

HAIKU_AGENTS="poppy"
# evelynn is excluded — she has no .claude/agents/evelynn.md (she is the top-level session, not a subagent)
OPUS_AGENTS="bard syndra pyke swain"
# All other agents in .claude/agents/ are assumed sonnet executors.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

extract_block() {
    # Extract text between BEGIN and END comments in a file.
    # $1 = file path, $2 = BEGIN marker substring, $3 = END marker substring
    local file="$1" begin_marker="$2" end_marker="$3"
    awk "/${begin_marker}/{found=1; next} /${end_marker}/{found=0} found" "$file"
}

drift_check() {
    local agent_file="$1" tier="$2" agent_name="$3"
    local begin_marker="BEGIN CANONICAL ${tier} RULES"
    local end_marker="END CANONICAL ${tier} RULES"

    # Check block exists
    if ! grep -q "$begin_marker" "$agent_file"; then
        echo "MISSING_BLOCK  $agent_name  (expected: BEGIN CANONICAL ${tier} RULES)"
        return 1
    fi

    # Extract actual block content
    actual="$(extract_block "$agent_file" "$begin_marker" "$end_marker")"

    # Select reference
    if [ "$tier" = "SONNET-EXECUTOR" ]; then
        ref="$SONNET_REF"
    else
        ref="$OPUS_REF"
    fi

    # Normalize whitespace for comparison (trim trailing spaces per line)
    actual_norm="$(printf '%s' "$actual" | sed 's/[[:space:]]*$//')"
    ref_norm="$(printf '%s' "$ref" | sed 's/[[:space:]]*$//')"

    if [ "$actual_norm" != "$ref_norm" ]; then
        echo "DRIFT          $agent_name"
        echo "  --- reference ---"
        printf '%s\n' "$ref_norm" | sed 's/^/  /'
        echo "  --- actual ---"
        printf '%s\n' "$actual_norm" | sed 's/^/  /'
        return 1
    fi

    echo "OK             $agent_name"
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [ ! -d "$AGENTS_DIR" ]; then
    echo "ERROR: .claude/agents/ not found at $AGENTS_DIR" >&2
    exit 2
fi

drift=0
ok=0
skipped=0

for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file" .md)"

    # Skip haiku agents — no canonical block expected
    skip=0
    for ha in $HAIKU_AGENTS; do
        if [ "$agent_name" = "$ha" ]; then
            echo "SKIP (haiku)   $agent_name"
            skip=1
            skipped=$((skipped + 1))
            break
        fi
    done
    [ "$skip" -eq 1 ] && continue

    # Classify tier
    tier="SONNET-EXECUTOR"
    for oa in $OPUS_AGENTS; do
        if [ "$agent_name" = "$oa" ]; then
            tier="OPUS-PLANNER"
            break
        fi
    done

    if drift_check "$agent_file" "$tier" "$agent_name"; then
        ok=$((ok + 1))
    else
        drift=$((drift + 1))
    fi
done

echo ""
echo "Results: $ok OK, $drift drift, $skipped skipped"

if [ "$drift" -gt 0 ]; then
    echo "FAIL: $drift agent(s) have rule drift. Update the canonical block in each file listed above."
    echo "Reference blocks are defined in scripts/lint-subagent-rules.sh (SONNET_REF / OPUS_REF)."
    exit 1
fi

echo "All agents clean."
exit 0
