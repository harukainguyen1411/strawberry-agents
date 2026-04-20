#!/usr/bin/env bash
# orianna-sign.sh — Orianna signing orchestrator.
#
# Plan: plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D7.1, T2.1
#
# Validates the plan is in the correct source directory for the requested phase,
# invokes the phase-appropriate Orianna prompt via claude CLI (NO mechanical
# fallback per §D9.2), and on clean check: computes the body hash, appends the
# orianna_signature_<phase> line to frontmatter, commits with Orianna's git
# author identity and the three required trailers (§D1.1). Does NOT push.
#
# Usage:
#   bash scripts/orianna-sign.sh <plan.md> <phase>
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
Usage: $0 <plan.md> <phase>

Signs a plan at the given lifecycle phase using Orianna's LLM gate check.
No mechanical fallback — if claude CLI is unavailable, signing is refused (§D9.2).

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
  log_stderr "check failed: $block_count block finding(s). Plan unchanged. Fix issues and re-run."
  log_stderr "Report: $latest_report"
  exit 1
fi

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

mv "$TMP_PLAN" "$PLAN_PATH"
log_stderr "appended $FIELD_NAME to frontmatter (hash=${BODY_HASH})"

# ---- Commit with Orianna's identity and required trailers ----------------

git -C "$REPO_ROOT" add "$PLAN_PATH"

git -C "$REPO_ROOT" \
  -c "user.name=$ORIANNA_NAME" \
  -c "user.email=$ORIANNA_EMAIL" \
  commit \
  -m "chore: orianna signature for ${PLAN_BASENAME}-${PHASE}" \
  --trailer "Signed-by: Orianna" \
  --trailer "Signed-phase: ${PHASE}" \
  --trailer "Signed-hash: sha256:${BODY_HASH}"

log_stderr "signed and committed: ${PLAN_BASENAME} phase=${PHASE} hash=${BODY_HASH}"
log_stderr "NOTE: signature committed but NOT pushed. Run 'git push' or let plan-promote.sh push."
exit 0
