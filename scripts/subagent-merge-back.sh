#!/usr/bin/env bash
# subagent-merge-back.sh — Reconcile a returned subagent's worktree branch into main.
#
# ADR: plans/approved/personal/2026-04-24-universal-worktree-isolation.md §Merge-back protocol
# Rule 10: POSIX-portable bash.
# Rule 11: Never rebase — uses --ff-only then --no-ff fallback, never rebase.
#
# Usage:
#   bash scripts/subagent-merge-back.sh <subagent-branch> [--worktree-path <path>]
#   bash scripts/subagent-merge-back.sh -h
#
# Three cases from ADR §Merge-back protocol:
#   (a) Subagent made no commits → noop + log.
#   (b) Subagent committed, main has not advanced → git merge --ff-only.
#   (c) Subagent committed, main has advanced (parallel merge) → git merge --no-ff.
#
# Conflict policy (ADR §Merge-back protocol case (c)):
#   - plans/**   → fail loud; exit non-zero with guidance.
#   - agents/**/memory/** → prefer last-sessions shards; coordinator must resolve.
#   - code (apps/**, scripts/**) → abort both merges; exit non-zero with guidance.
#
# After a successful merge, deletes the subagent branch locally and on origin.
# Does NOT prune the worktree — harness handles that.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export REPO_ROOT

# ── helpers ────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: bash scripts/subagent-merge-back.sh <subagent-branch> [--worktree-path <path>]

Reconcile a returned subagent's worktree branch back into main.

Options:
  -h, --help              Show this help message and exit.
  --worktree-path <path>  Path to the worktree (informational only; logged).

Exits 0 on success (including noop for case a).
Exits non-zero on conflict or unexpected error.
EOF
}

log() { printf '[subagent-merge-back] %s\n' "$*"; }
warn() { printf '[subagent-merge-back] WARN: %s\n' "$*" >&2; }
die() { printf '[subagent-merge-back] ERROR: %s\n' "$*" >&2; exit 1; }

# Cleanup: push main to origin, delete subagent branch locally + remotely.
# Called after a successful merge.
# Requires: SUBAGENT_BRANCH, BRANCH_LOCAL, BRANCH_REMOTE are set.
do_cleanup() {
    log "Pushing main to origin..."
    git push origin main 2>&1 | while IFS= read -r line; do log "  push: $line"; done

    if [ -n "$BRANCH_REMOTE" ]; then
        log "Deleting remote branch origin/$SUBAGENT_BRANCH..."
        git push origin --delete "$SUBAGENT_BRANCH" 2>&1 | while IFS= read -r line; do log "  push: $line"; done || warn "Remote branch delete failed (may already be gone)"
    fi
    if [ -n "$BRANCH_LOCAL" ]; then
        log "Deleting local branch $SUBAGENT_BRANCH..."
        git branch -d "$SUBAGENT_BRANCH" 2>&1 || warn "Local branch delete failed (may be in use by a worktree)"
    fi
    log "Subagent branch $SUBAGENT_BRANCH reconciled into main."
}

# ── argument parsing ────────────────────────────────────────────────────────────

SUBAGENT_BRANCH=""
WORKTREE_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --worktree-path)
            shift
            WORKTREE_PATH="${1:-}"
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            if [ -z "$SUBAGENT_BRANCH" ]; then
                SUBAGENT_BRANCH="$1"
            else
                die "Unexpected argument: $1"
            fi
            ;;
    esac
    shift
done

if [ -z "$SUBAGENT_BRANCH" ]; then
    usage
    exit 1
fi

if [ -n "$WORKTREE_PATH" ]; then
    log "Worktree path: $WORKTREE_PATH"
fi

log "Reconciling branch: $SUBAGENT_BRANCH"

# ── fetch ───────────────────────────────────────────────────────────────────────

log "Fetching origin..."
git fetch origin 2>&1 | while IFS= read -r line; do log "  fetch: $line"; done || true

# ── check if branch exists (locally or on origin) ───────────────────────────────

BRANCH_LOCAL=""
BRANCH_REMOTE=""

if git rev-parse --verify "refs/heads/$SUBAGENT_BRANCH" >/dev/null 2>&1; then
    BRANCH_LOCAL="yes"
fi
if git rev-parse --verify "refs/remotes/origin/$SUBAGENT_BRANCH" >/dev/null 2>&1; then
    BRANCH_REMOTE="yes"
fi

if [ -z "$BRANCH_LOCAL" ] && [ -z "$BRANCH_REMOTE" ]; then
    die "Branch '$SUBAGENT_BRANCH' not found locally or on origin."
fi

# Resolve the branch tip SHA (prefer remote if available, local as fallback)
if [ -n "$BRANCH_REMOTE" ]; then
    BRANCH_TIP="$(git rev-parse "origin/$SUBAGENT_BRANCH")"
else
    BRANCH_TIP="$(git rev-parse "refs/heads/$SUBAGENT_BRANCH")"
fi

# ── determine current main tip ──────────────────────────────────────────────────

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "main" ]; then
    die "Must be run from the main branch. Current branch: $CURRENT_BRANCH"
fi

MAIN_TIP="$(git rev-parse HEAD)"
log "main tip: $MAIN_TIP"
log "subagent branch tip: $BRANCH_TIP"

# ── case (a): no commits — branch tip is ancestor of main ──────────────────────

# If subagent branch tip is already reachable from main HEAD, no new work.
if git merge-base --is-ancestor "$BRANCH_TIP" "$MAIN_TIP" 2>/dev/null; then
    log "Case (a): subagent made no new commits (branch tip is ancestor of main). Noop."
    if [ -n "$BRANCH_REMOTE" ]; then
        log "Deleting remote branch origin/$SUBAGENT_BRANCH..."
        git push origin --delete "$SUBAGENT_BRANCH" 2>&1 | while IFS= read -r line; do log "  push: $line"; done || warn "Remote branch delete failed (may already be gone)"
    fi
    if [ -n "$BRANCH_LOCAL" ]; then
        log "Deleting local branch $SUBAGENT_BRANCH..."
        git branch -d "$SUBAGENT_BRANCH" 2>&1 || warn "Local branch delete failed"
    fi
    log "Done. Main remains at: $MAIN_TIP"
    exit 0
fi

# ── case (b): main has not advanced — fast-forward possible ────────────────────

MERGE_BASE="$(git merge-base HEAD "$BRANCH_TIP" 2>/dev/null || true)"
if [ "$MERGE_BASE" = "$MAIN_TIP" ]; then
    log "Case (b): main has not advanced. Attempting --ff-only merge..."
    if [ -n "$BRANCH_REMOTE" ]; then
        MERGE_REF="origin/$SUBAGENT_BRANCH"
    else
        MERGE_REF="$SUBAGENT_BRANCH"
    fi
    git merge --ff-only "$MERGE_REF"
    NEW_MAIN="$(git rev-parse HEAD)"
    log "Fast-forward merge succeeded. main is now: $NEW_MAIN"
    do_cleanup
    exit 0
fi

# ── case (c): main has advanced — use --no-ff (Rule 11: never rebase) ──────────

log "Case (c): main has advanced since branch was cut. Attempting --no-ff merge..."
if [ -n "$BRANCH_REMOTE" ]; then
    MERGE_REF="origin/$SUBAGENT_BRANCH"
else
    MERGE_REF="$SUBAGENT_BRANCH"
fi

# Attempt the merge; detect conflicts.
# Note: set -e is active; git merge returns non-zero on conflict, so we use || true.
git merge --no-ff "$MERGE_REF" --no-edit 2>&1 || true

# Check if we are in a conflicted state.
CONFLICTED_FILES="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"

if [ -z "$CONFLICTED_FILES" ]; then
    # Merge succeeded cleanly.
    NEW_MAIN="$(git rev-parse HEAD)"
    log "No-ff merge succeeded. main is now: $NEW_MAIN"
    do_cleanup
    exit 0
fi

# Conflict detected — inspect which files are conflicted and apply policy.
log "Merge conflict detected in: $CONFLICTED_FILES"

HAS_PLAN_CONFLICT=""
HAS_CODE_CONFLICT=""
HAS_MEMORY_CONFLICT=""
HAS_OTHER_CONFLICT=""

for f in $CONFLICTED_FILES; do
    case "$f" in
        plans/*)
            HAS_PLAN_CONFLICT="yes"
            ;;
        apps/*|scripts/*)
            HAS_CODE_CONFLICT="yes"
            ;;
        agents/*/memory/*)
            HAS_MEMORY_CONFLICT="yes"
            ;;
        *)
            HAS_OTHER_CONFLICT="yes"
            ;;
    esac
done

# Abort the merge in all conflict cases — coordinator must resolve manually.
git merge --abort 2>/dev/null || true

if [ -n "$HAS_PLAN_CONFLICT" ]; then
    die "CONFLICT in plans/**. Two parallel plan authors touched the same slug — this is a coordination bug. Abort both merges and report to Duong for manual resolution. Conflicted files: $CONFLICTED_FILES"
fi

if [ -n "$HAS_CODE_CONFLICT" ]; then
    die "CONFLICT in code (apps/**, scripts/**). Abort both merges and re-dispatch one subagent on top of the merged result of the other. Conflicted files: $CONFLICTED_FILES"
fi

if [ -n "$HAS_MEMORY_CONFLICT" ]; then
    die "CONFLICT in memory (agents/**/memory/**). Prefer last-sessions shards over main memory file — two agents should not both modify the main memory file mid-session. Conflicted files: $CONFLICTED_FILES"
fi

# Unknown conflict location.
die "CONFLICT in unexpected files. Merge aborted. Conflicted files: $CONFLICTED_FILES"
