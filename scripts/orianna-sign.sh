#!/usr/bin/env bash
# orianna-sign.sh — Orianna signing orchestrator.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D7.1, T2.1
# Plan: plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T5, T10
#
# Validates the plan is in the correct source directory for the requested phase,
# invokes the phase-appropriate Orianna prompt via claude CLI (NO mechanical
# fallback per §D9.2), and on clean check: computes the body hash, appends the
# orianna_signature_<phase> line to frontmatter, commits with Orianna's git
# author identity and the three required trailers (§D1.1). Does NOT push.
#
# Usage:
#   bash scripts/orianna-sign.sh [--pre-fix|--no-pre-fix] <plan.md> <phase>
#
# Flags:
#   --pre-fix     Run orianna-pre-fix.sh before the claude check. If rewrites
#                 are applied, the commit uses shape B (body + signature in one
#                 atomic commit with Signed-Fix: <phase> trailer). Default: on
#                 for concern: work plans; off otherwise.
#   --no-pre-fix  Explicitly disable the pre-fix pass.
#
# <phase> must be: approved, in_progress, or implemented
#
# Source directories expected per phase:
#   approved     → plans/proposed/
#   in_progress  → plans/approved/
#   implemented  → plans/in-progress/
#
# Exit codes:
#   0 — signed successfully (signature appended, commit created)
#   1 — Orianna check failed (block findings — plan unchanged)
#   2 — invocation/setup error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Honor REPO env var if set (used by test harnesses that operate on a temp repo).
# Otherwise default to the repo containing this script.
if [ -n "${REPO:-}" ] && [ -d "${REPO}" ]; then
  REPO_ROOT="$(cd "$REPO" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

ORIANNA_HASH_BODY="$SCRIPT_DIR/orianna-hash-body.sh"
ORIANNA_VERIFY="$SCRIPT_DIR/orianna-verify-signature.sh"
ORIANNA_PRE_FIX="$SCRIPT_DIR/orianna-pre-fix.sh"
STALE_LOCK_LIB="$SCRIPT_DIR/_lib_stale_lock.sh"

ORIANNA_NAME="Orianna (agent)"
ORIANNA_EMAIL="orianna@agents.strawberry.local"

# ---- helpers ---------------------------------------------------------------

log_stderr() { printf '[orianna-sign] %s\n' "$*" >&2; }

die() {
  log_stderr "ERROR: $*"
  exit 2
}

usage() {
  cat >&2 <<EOF
Usage: $0 [--pre-fix|--no-pre-fix] <plan.md> <phase>

Signs a plan at the given lifecycle phase using Orianna's LLM gate check.
No mechanical fallback — if claude CLI is unavailable, signing is refused (§D9.2).

Flags:
  --pre-fix     Run orianna-pre-fix.sh before claude check (default: on for
                concern:work plans, off otherwise).
  --no-pre-fix  Disable the pre-fix pass.

<phase> must be: approved, in_progress, or implemented

Phase → source directory mapping:
  approved     → plan must be in plans/proposed/
  in_progress  → plan must be in plans/approved/
  implemented  → plan must be in plans/in-progress/

Exit codes: 0=signed, 1=check failed (plan unchanged), 2=invocation error
EOF
  exit 2
}

# ---- argument validation ---------------------------------------------------

# Parse optional flags
PRE_FIX_FLAG=""  # empty = auto-detect from frontmatter; "1" = on; "0" = off
while [ $# -gt 0 ]; do
  case "$1" in
    --pre-fix)   PRE_FIX_FLAG="1"; shift ;;
    --no-pre-fix) PRE_FIX_FLAG="0"; shift ;;
    --) shift; break ;;
    -*) die "unknown flag: $1" ;;
    *) break ;;
  esac
done

[ $# -eq 2 ] || usage
PLAN_ARG="$1"
PHASE="$2"

case "$PHASE" in
  approved|in_progress|implemented) ;;
  *)
    die "unknown phase '$PHASE': must be approved, in_progress, or implemented"
    ;;
esac

# Resolve plan path
case "$PLAN_ARG" in
  /*) PLAN_PATH="$PLAN_ARG" ;;
  *)  PLAN_PATH="$REPO_ROOT/$PLAN_ARG" ;;
esac

[ -f "$PLAN_PATH" ] || die "plan file not found: $PLAN_PATH"
case "$PLAN_PATH" in
  *.md) ;;
  *) die "plan file must end in .md (got $PLAN_PATH)" ;;
esac

PLAN_REL="${PLAN_PATH#"$REPO_ROOT/"}"

# ---- CHECK: plan is in the correct source directory for this phase --------

case "$PHASE" in
  approved)
    EXPECTED_DIR="plans/proposed"
    ;;
  in_progress)
    EXPECTED_DIR="plans/approved"
    ;;
  implemented)
    EXPECTED_DIR="plans/in-progress"
    ;;
esac

PLAN_DIR="$(dirname "$PLAN_REL")"

# Accept both flat layout (plans/<phase>/<file>.md) and concern-subdir layout
# (plans/<phase>/{work,personal}/<file>.md).
_plan_dir_ok=0
if [ "$PLAN_DIR" = "$EXPECTED_DIR" ]; then
  _plan_dir_ok=1
else
  case "$PLAN_DIR" in
    "${EXPECTED_DIR}/work"|"${EXPECTED_DIR}/personal") _plan_dir_ok=1 ;;
  esac
fi

if [ "$_plan_dir_ok" -eq 0 ]; then
  die "phase '$PHASE' requires plan to be in $EXPECTED_DIR/ (or $EXPECTED_DIR/{work,personal}/) but plan is in $PLAN_DIR/. Move the plan to the correct directory first."
fi

# ---- CHECK: signature field not already present (idempotency guard) -------

FIELD_NAME="orianna_signature_${PHASE}"
if awk "BEGIN{d=0} /^---[[:space:]]*\$/{d++; if(d==2) exit; next} d==1 && /^${FIELD_NAME}:/{found=1; exit} END{exit !found}" "$PLAN_PATH" 2>/dev/null; then
  die "plan already has '$FIELD_NAME' in frontmatter. To re-sign after a body edit, remove the field first and re-run."
fi

# ---- CHECK: carry-forward signatures for phases past approved --------------

if [ "$PHASE" = "in_progress" ] || [ "$PHASE" = "implemented" ]; then
  log_stderr "verifying approved-signature carry-forward..."
  if ! bash "$ORIANNA_VERIFY" "$PLAN_PATH" approved >/dev/null 2>&1; then
    _err="$(bash "$ORIANNA_VERIFY" "$PLAN_PATH" approved 2>&1 || true)"
    die "approved-signature invalid or missing: $_err. Cannot sign $PHASE until approved signature is valid."
  fi
fi

if [ "$PHASE" = "implemented" ]; then
  log_stderr "verifying in-progress-signature carry-forward..."
  if ! bash "$ORIANNA_VERIFY" "$PLAN_PATH" in_progress >/dev/null 2>&1; then
    _err="$(bash "$ORIANNA_VERIFY" "$PLAN_PATH" in_progress 2>&1 || true)"
    die "in-progress-signature invalid or missing: $_err. Cannot sign implemented until both prior signatures are valid."
  fi
fi

# ---- Stale git index.lock auto-recovery (T7) --------------------------------
# Source the stale-lock helper if present (POSIX-compatible dot-include).
if [ -f "$STALE_LOCK_LIB" ]; then
  # shellcheck source=_lib_stale_lock.sh
  . "$STALE_LOCK_LIB"
  GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --git-dir)" maybe_clear_stale_lock
fi

# ---- Source coordinator lock lib (T4 — concurrent-coordinator-race-closeout) -
# Load the shared lock helper now; the lock itself is acquired just before
# git add (see the comment near git -C "$REPO_ROOT" add "$PLAN_PATH" below).
_COORD_LOCK_LIB="$SCRIPT_DIR/_lib_coordinator_lock.sh"
if [ -f "$_COORD_LOCK_LIB" ]; then
  # shellcheck source=_lib_coordinator_lock.sh
  . "$_COORD_LOCK_LIB"
fi

# ---- Pre-fix pass (T9/T10) — optional body rewrites before claude check ----
# Determine whether to run pre-fix based on flag or plan frontmatter.
PRE_FIX_APPLIED=0  # 1 if pre-fix made any changes
if [ "$PRE_FIX_FLAG" = "0" ]; then
  _run_pre_fix=0
elif [ "$PRE_FIX_FLAG" = "1" ]; then
  _run_pre_fix=1
else
  # Auto-detect: on for concern:work plans, off otherwise.
  _plan_concern="$(awk 'BEGIN{d=0} /^---[[:space:]]*$/{d++; if(d==2) exit; next} d==1 && /^concern:/{sub(/^concern:[[:space:]]*/,""); print; exit}' "$PLAN_PATH" 2>/dev/null || echo '')"
  if [ "$_plan_concern" = "work" ]; then
    _run_pre_fix=1
  else
    _run_pre_fix=0
  fi
fi

# Snapshot the plan before any pre-fix mutations so we can restore on
# block-findings exit (Rule 1 — no uncommitted tree changes after refused sign).
# Plan: plans/in-progress/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md T2
_PLAN_SNAPSHOT="$(mktemp)"
cp "$PLAN_PATH" "$_PLAN_SNAPSHOT"

if [ "$_run_pre_fix" -eq 1 ] && [ -f "$ORIANNA_PRE_FIX" ]; then
  log_stderr "running pre-fix pass on: $PLAN_REL"
  _pre_fix_stdout="$(bash "$ORIANNA_PRE_FIX" "$PLAN_PATH" 2>/dev/null || true)"
  if [ -n "$_pre_fix_stdout" ]; then
    log_stderr "pre-fix rewrites applied: $_pre_fix_stdout"
    PRE_FIX_APPLIED=1
  else
    log_stderr "pre-fix: no rewrites needed"
  fi
fi

# ---- Determine phase-specific prompt --------------------------------------

case "$PHASE" in
  approved)
    PROMPT_FILE="$REPO_ROOT/agents/orianna/prompts/plan-check.md"
    PROMPT_LABEL="plan-check (proposed→approved)"
    ;;
  in_progress)
    PROMPT_FILE="$REPO_ROOT/agents/orianna/prompts/task-gate-check.md"
    PROMPT_LABEL="task-gate-check (approved→in-progress)"
    ;;
  implemented)
    PROMPT_FILE="$REPO_ROOT/agents/orianna/prompts/implementation-gate-check.md"
    PROMPT_LABEL="implementation-gate-check (in-progress→implemented)"
    ;;
esac

# ---- CHECK: claude CLI available (§D9.2 — no fallback, checked FIRST) ----
# Must be before prompt-file check so offline-fail produces a clear "signature
# unavailable" message even if prompt files are absent (e.g. in test repos).

if ! command -v claude >/dev/null 2>&1; then
  log_stderr "signature unavailable: claude CLI not found (§D9.2). No mechanical fallback for signing. Retry when connectivity is restored."
  exit 1
fi

[ -f "$PROMPT_FILE" ] || die "phase prompt not found: $PROMPT_FILE"

# ---- Invoke phase-appropriate Orianna check via claude CLI ----------------

log_stderr "invoking Orianna ($PROMPT_LABEL) on: $PLAN_REL"

PROMPT=$(cat "$PROMPT_FILE")
FULL_PROMPT="${PROMPT}

---

## Plan to check

Plan path (relative to repo root): \`${PLAN_REL}\`
Absolute path: \`${PLAN_PATH}\`

Begin the gate check now. Read the plan, apply all checks in this prompt,
and write the report to assessments/plan-fact-checks/ as specified.
Then exit with the appropriate status code (0=clean, 1=block, 2=error).
"

REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

claude_exit=0
claude \
  -p \
  --dangerously-skip-permissions \
  --system-prompt "You are Orianna, the plan gate-checker for the strawberry agent system. Your working directory is $REPO_ROOT." \
  "$FULL_PROMPT" \
  2>>"$REPO_ROOT/.orianna-sign-stderr.tmp" || claude_exit=$?

rm -f "$REPO_ROOT/.orianna-sign-stderr.tmp"

if [ "$claude_exit" -eq 2 ]; then
  log_stderr "claude CLI returned exit code 2 (invocation error)"
  exit 2
fi

# Find the report written by Orianna
PLAN_BASENAME="$(basename "$PLAN_PATH" .md)"
latest_report=""
for f in "$REPORT_DIR"/${PLAN_BASENAME}-[0-9]*.md; do
  [ -f "$f" ] && latest_report="$f"
done

if [ -z "$latest_report" ]; then
  log_stderr "WARNING: no report found in $REPORT_DIR for plan $PLAN_BASENAME"
  log_stderr "claude may have exited without writing the report"
  exit 2
fi

log_stderr "report: $latest_report"

# Extract block_findings count from report frontmatter
block_count=0
if [ -f "$latest_report" ]; then
  block_count=$(awk '/^---/{n++; if(n==2) exit} /^block_findings:/{gsub(/^block_findings:[[:space:]]*/,""); print}' "$latest_report" || echo 0)
  block_count="${block_count:-0}"
fi

log_stderr "block findings: ${block_count}"

if [ "$block_count" -gt 0 ] || [ "$claude_exit" -eq 1 ]; then
  # Restore plan from snapshot so pre-fix mutations don't linger (Rule 1).
  if [ -f "$_PLAN_SNAPSHOT" ]; then
    cp "$_PLAN_SNAPSHOT" "$PLAN_PATH"
    rm -f "$_PLAN_SNAPSHOT"
    log_stderr "plan restored to pre-sign state (snapshot/restore — T2)"
  fi
  log_stderr "check failed: $block_count block finding(s). Plan unchanged. Fix issues and re-run."
  log_stderr "Report: $latest_report"
  exit 1
fi

# Discard snapshot — sign succeeded, mutations are intentional.
rm -f "$_PLAN_SNAPSHOT"

# ---- All checks passed — compute hash and append signature ----------------

log_stderr "check passed — computing body hash and signing..."

[ -f "$ORIANNA_HASH_BODY" ] || die "orianna-hash-body.sh not found: $ORIANNA_HASH_BODY"

BODY_HASH="$(bash "$ORIANNA_HASH_BODY" "$PLAN_PATH")"
ISO_TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
SIG_VALUE="sha256:${BODY_HASH}:${ISO_TS}"
SIG_LINE="${FIELD_NAME}: \"${SIG_VALUE}\""

# Append signature to frontmatter: insert before the closing '---' delimiter
# (the second '---' line in the file).
TMP_PLAN="$(mktemp)"
awk -v sigline="$SIG_LINE" '
  BEGIN { dashes=0; inserted=0 }
  /^---[[:space:]]*$/ {
    dashes++
    if (dashes == 2 && !inserted) {
      print sigline
      inserted = 1
    }
    print
    next
  }
  { print }
' "$PLAN_PATH" > "$TMP_PLAN"

# Verify the signature line was actually inserted
if ! grep -qF "$SIG_LINE" "$TMP_PLAN"; then
  rm -f "$TMP_PLAN"
  die "failed to insert signature line into frontmatter — plan may lack proper --- delimiters"
fi

# ---- Coordinator advisory lock (T4 — concurrent-coordinator-race-closeout) --
# Acquire the shared lock before writing the signature to disk and before the
# git add→commit window. This serialises concurrent orianna-sign.sh and
# plan-promote.sh invocations, preventing cross-agent index races and ensuring
# the signature write + commit is atomic relative to other coordinators.
# Lockfile lives under .git/ (never tracked).
# See: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T4
if command -v coordinator_lock_acquire >/dev/null 2>&1; then
  coordinator_lock_acquire "$REPO_ROOT/.git/strawberry-promote.lock"
else
  log_stderr "WARNING: coordinator_lock_acquire not available — running without coordinator lock (race risk)"
fi

mv "$TMP_PLAN" "$PLAN_PATH"
log_stderr "appended $FIELD_NAME to frontmatter (hash=${BODY_HASH})"

# ---- Commit with Orianna's identity and required trailers ----------------
# Shape B (T5): when pre-fix rewrites were applied in this invocation, combine
# body edits and signature into one atomic commit with a Signed-Fix: trailer.
# Shape A: signature-only commit (original shape, no pre-fix edits).

git -C "$REPO_ROOT" add "$PLAN_PATH"

if [ "${PRE_FIX_APPLIED:-0}" -eq 1 ]; then
  # Shape B — atomic body + signature commit
  COMMIT_MSG="chore: orianna signature for ${PLAN_BASENAME}-${PHASE}

Signed-Fix: ${PHASE}
Signed-by: Orianna
Signed-phase: ${PHASE}
Signed-hash: sha256:${BODY_HASH}"
  log_stderr "shape B commit (pre-fix rewrites included)"
else
  # Shape A — signature-only commit
  COMMIT_MSG="chore: orianna signature for ${PLAN_BASENAME}-${PHASE}

Signed-by: Orianna
Signed-phase: ${PHASE}
Signed-hash: sha256:${BODY_HASH}"
fi

# Write COMMIT_EDITMSG before git commit so the pre-commit hook (which runs before
# git prepares the message internally) can inspect the trailers.
GIT_DIR_PATH="$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir)"
printf '%s\n' "$COMMIT_MSG" > "${GIT_DIR_PATH}/COMMIT_EDITMSG"

# STAGED_SCOPE support (plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md):
# When STAGED_SCOPE is set, scope the commit to exactly the plan path via a git pathspec.
# This prevents concurrent coordinator sessions' staged files from riding along into the
# signing commit and triggering the one-file guard in pre-commit-orianna-signature-guard.sh.
#
# Auto-derive (T5 — concurrent-coordinator-race-closeout): if STAGED_SCOPE is unset,
# default it to PLAN_REL so the commit is always path-scoped. Explicit caller-set
# values still win. This makes the contract self-sufficient regardless of caller.
if [ -z "${STAGED_SCOPE:-}" ]; then
  STAGED_SCOPE="$PLAN_REL"
  export STAGED_SCOPE
  log_stderr "STAGED_SCOPE auto-derived from PLAN_REL: $STAGED_SCOPE"
fi
if [ -n "${STAGED_SCOPE:-}" ]; then
  # Validate: must be a relative path that stays within REPO_ROOT
  case "$STAGED_SCOPE" in
    /*) die "STAGED_SCOPE must be a repo-relative path, not absolute: $STAGED_SCOPE" ;;
    *"../"*|*"/.."*|"..") die "STAGED_SCOPE must not contain path traversal (..): $STAGED_SCOPE" ;;
    *) ;;
  esac
  if [ ! -f "$REPO_ROOT/$STAGED_SCOPE" ]; then
    die "STAGED_SCOPE path not found in repo: $STAGED_SCOPE"
  fi
  log_stderr "scoping commit to $STAGED_SCOPE"
  git -C "$REPO_ROOT" \
    -c "user.name=$ORIANNA_NAME" \
    -c "user.email=$ORIANNA_EMAIL" \
    commit \
    -m "$COMMIT_MSG" \
    -- "$STAGED_SCOPE"
else
  git -C "$REPO_ROOT" \
    -c "user.name=$ORIANNA_NAME" \
    -c "user.email=$ORIANNA_EMAIL" \
    commit \
    -m "$COMMIT_MSG"
fi

log_stderr "signed and committed: ${PLAN_BASENAME} phase=${PHASE} hash=${BODY_HASH}"
log_stderr "NOTE: signature committed but NOT pushed. Run 'git push' or let plan-promote.sh push."
exit 0
