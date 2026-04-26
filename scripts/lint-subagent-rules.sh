#!/usr/bin/env bash
# lint-subagent-rules.sh
# Diff the canonical inline rule block from each .claude/agents/*.md against
# reference blocks for Sonnet-executor and Opus-planner agents.
# Also checks _shared/*.md files for duplicate <!-- include: --> markers (§D4.2).
#
# Usage: bash scripts/lint-subagent-rules.sh [--agents-dir <path>] [--fix]
#   --agents-dir <path>  Override the agent definitions directory.
#                        Defaults to <repo-root>/.claude/agents/
#   --fix  (not implemented) would auto-update the canonical blocks
#
# Exit codes:
#   0 — all agents clean, no duplicate markers in shared files
#   1 — one or more agents have drift or shared files have duplicate markers
#   2 — usage error
#
# POSIX-portable bash. Runs on macOS and Git Bash on Windows.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir)
      shift
      AGENTS_DIR="$1"
      shift
      ;;
    --fix)
      shift
      # Not implemented
      ;;
    *)
      printf 'lint-subagent-rules: unknown argument: %s\n' "$1" >&2
      printf 'Usage: bash lint-subagent-rules.sh [--agents-dir <path>] [--fix]\n' >&2
      exit 2
      ;;
  esac
done

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

HAIKU_AGENTS="skarner"
OPUS_AGENTS="azir kayn aphelios caitlyn lulu neeko heimerdinger camille lux swain evelynn lucian karma orianna senna xayah sona"
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

# check_shared_marker_duplicates <shared_dir>
# Checks every *.md file in <shared_dir> for duplicate <!-- include: --> markers
# referencing the same target (§D4.2 single-marker invariant).
# Prints violations and returns 1 if any found, 0 otherwise.
check_shared_marker_duplicates() {
    local shared_dir="$1"
    local found_dup=0

    if [ ! -d "$shared_dir" ]; then
        return 0
    fi

    for shared_file in "$shared_dir"/*.md; do
        [ -f "$shared_file" ] || continue
        local shared_name
        shared_name="$(basename "$shared_file")"

        # Extract all include targets and check for duplicates
        # Use sort | uniq -d to find targets appearing more than once
        local targets
        targets="$(grep -o '<!-- include: _shared/[^>]*\.md -->' "$shared_file" 2>/dev/null || true)"
        if [ -z "$targets" ]; then
            continue
        fi

        local dups
        dups="$(printf '%s\n' "$targets" | sort | uniq -d)"
        if [ -n "$dups" ]; then
            echo "DUPLICATE_MARKER  $shared_name"
            printf '%s\n' "$dups" | sed 's/^/  dup: /'
            found_dup=1
        fi
    done

    return "$found_dup"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [ ! -d "$AGENTS_DIR" ]; then
    echo "ERROR: .claude/agents/ not found at $AGENTS_DIR" >&2
    exit 2
fi

SHARED_DIR="$AGENTS_DIR/_shared"

drift=0
ok=0
skipped=0

# --- Phase 1: canonical block drift check on agent defs ---
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

# --- Phase 2: duplicate include marker check in _shared/*.md (§D4.2) ---
marker_errors=0
if ! check_shared_marker_duplicates "$SHARED_DIR"; then
    marker_errors=1
fi

echo ""
echo "Results: $ok OK, $drift drift, $skipped skipped"

if [ "$drift" -gt 0 ]; then
    echo "FAIL: $drift agent(s) have rule drift. Update the canonical block in each file listed above."
    echo "Reference blocks are defined in scripts/lint-subagent-rules.sh (SONNET_REF / OPUS_REF)."
fi

if [ "$marker_errors" -gt 0 ]; then
    echo "FAIL: duplicate <!-- include: --> markers found in _shared/ files (§D4.2 single-marker invariant)."
fi

if [ "$drift" -gt 0 ] || [ "$marker_errors" -gt 0 ]; then
    exit 1
fi

echo "All agents clean."
exit 0
