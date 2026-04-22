#!/usr/bin/env bash
# test-orianna-sign-staged-scope.sh — xfail test for STAGED_SCOPE env-var support
# in scripts/orianna-sign.sh.
#
# Plan: plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md T1
#
# xfail: STAGED_SCOPE — test fails against unpatched orianna-sign.sh (no STAGED_SCOPE
# support). Once T2 patches the script this test must pass (exit 0).
#
# Usage:
#   bash scripts/__tests__/test-orianna-sign-staged-scope.sh
#
# Exit codes:
#   0 — all assertions passed (STAGED_SCOPE works correctly)
#   1 — test assertion failed
#   2 — test setup/infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIANNA_SIGN="$REPO_ROOT/scripts/orianna-sign.sh"

# --- helpers -----------------------------------------------------------------

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# --- setup temp repo ---------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
TMPBIN="$TMPDIR_ROOT/bin"
TMPREPO="$TMPDIR_ROOT/repo"

cleanup() {
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMPBIN"
mkdir -p "$TMPREPO"

# Initialise a bare git repo (no remotes needed; orianna-sign.sh does not push)
git -C "$TMPREPO" init -q
git -C "$TMPREPO" config user.email "test@test.local"
git -C "$TMPREPO" config user.name "Test"

# Initial empty commit so HEAD exists
git -C "$TMPREPO" commit -q --allow-empty -m "init"

# Install the real pre-commit hook (orianna-signature-guard) so the commit is
# properly validated — this is the guard that rejects multi-file Orianna commits.
HOOKS_DIR="$TMPREPO/.git/hooks"
mkdir -p "$HOOKS_DIR"
cp "$REPO_ROOT/scripts/hooks/pre-commit-orianna-signature-guard.sh" \
   "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Create supporting scripts that orianna-sign.sh expects (hash-body, verify)
# by symlinking from the real repo so they work in the temp repo.
mkdir -p "$TMPREPO/scripts"
ln -s "$REPO_ROOT/scripts/orianna-hash-body.sh" "$TMPREPO/scripts/orianna-hash-body.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"

# Create prompt dir and stub prompt file
mkdir -p "$TMPREPO/agents/orianna/prompts"
printf 'Stub plan-check prompt for test.\n' \
  > "$TMPREPO/agents/orianna/prompts/plan-check.md"

# Create report dir
mkdir -p "$TMPREPO/assessments/plan-fact-checks"

# Seed a minimal v2 plan under plans/proposed/
PLAN_DIR="$TMPREPO/plans/proposed"
mkdir -p "$PLAN_DIR"
PLAN_FILE="$PLAN_DIR/2026-04-22-staged-scope-test-plan.md"
cat > "$PLAN_FILE" <<'PLANEOF'
---
status: proposed
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
---

# Staged scope test plan

This is a minimal plan used by the STAGED_SCOPE test harness.
It exists only in the temp repo and is never committed to the real repo.
PLANEOF

git -C "$TMPREPO" add "$PLAN_FILE"
git -C "$TMPREPO" commit -q -m "chore: seed test plan"

PLAN_REL="plans/proposed/2026-04-22-staged-scope-test-plan.md"

# Stub claude CLI: writes a clean Orianna report (block_findings: 0) and exits 0.
# Extracts REPO_ROOT from --system-prompt and plan basename from the full prompt arg.
cat > "$TMPBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
# Stub claude CLI for test harness — emits a clean Orianna report.

REPORT_REPO=""
NEXT_IS_SYSPROMPT=0
LAST_ARG=""
for arg in "$@"; do
  if [ "$NEXT_IS_SYSPROMPT" -eq 1 ]; then
    REPORT_REPO="${arg#*Your working directory is }"
    REPORT_REPO="${REPORT_REPO%.}"
    REPORT_REPO="${REPORT_REPO%% }"
    NEXT_IS_SYSPROMPT=0
  fi
  case "$arg" in --system-prompt) NEXT_IS_SYSPROMPT=1 ;; esac
  LAST_ARG="$arg"
done

PLAN_BASENAME=""
while IFS= read -r line; do
  case "$line" in
    *"Plan path (relative to repo root):"*)
      _rel="${line#*\`}"
      _rel="${_rel%\`*}"
      PLAN_BASENAME="$(basename "$_rel" .md)"
      break
      ;;
  esac
done <<EOF
$LAST_ARG
EOF

if [ -z "$REPORT_REPO" ]; then
  printf '[stub-claude] ERROR: could not determine repo root from --system-prompt arg\n' >&2
  exit 2
fi
if [ -z "$PLAN_BASENAME" ]; then
  printf '[stub-claude] ERROR: could not determine plan basename from prompt\n' >&2
  exit 2
fi

REPORT_DIR="$REPORT_REPO/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"
TS="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
REPORT_FILE="$REPORT_DIR/${PLAN_BASENAME}-${TS}.md"

cat > "$REPORT_FILE" <<EOF
---
plan: $PLAN_BASENAME
phase: approved
block_findings: 0
warn_findings: 0
timestamp: $TS
---

## Summary

Stub check: no findings. Test harness report.

## Block findings

None.

## Warn findings

None.
EOF

exit 0
STUBEOF
chmod +x "$TMPBIN/claude"

# --- Stage a noise file (simulates concurrent coordinator staged work) -------

NOISE_FILE="$TMPREPO/noise.txt"
printf 'noise from concurrent session\n' > "$NOISE_FILE"
git -C "$TMPREPO" add "$NOISE_FILE"

info "noise.txt staged in index"

# Verify noise.txt is staged
STAGED_BEFORE="$(git -C "$TMPREPO" diff --cached --name-only)"
if ! printf '%s\n' "$STAGED_BEFORE" | grep -q "noise.txt"; then
  printf '[ERROR] noise.txt not staged before running orianna-sign.sh\n' >&2
  exit 2
fi

# --- Invoke orianna-sign.sh with STAGED_SCOPE --------------------------------

info "invoking orianna-sign.sh with STAGED_SCOPE=$PLAN_REL"

SIGN_RC=0
REPO="$TMPREPO" STAGED_SCOPE="$PLAN_REL" \
  PATH="$TMPBIN:$PATH" \
  bash "$ORIANNA_SIGN" "$PLAN_FILE" approved 2>&1 || SIGN_RC=$?

if [ "$SIGN_RC" -ne 0 ]; then
  fail "orianna-sign.sh exited $SIGN_RC (expected 0). STAGED_SCOPE may not be implemented yet."
fi

# --- Assertion 1: HEAD commit touches exactly the plan file ------------------

HEAD_FILES="$(git -C "$TMPREPO" show --name-only --format='' HEAD)"
HEAD_FILE_COUNT="$(printf '%s\n' "$HEAD_FILES" | grep -c '[^[:space:]]' || echo 0)"

info "HEAD commit files: $HEAD_FILES"

if [ "$HEAD_FILE_COUNT" -ne 1 ]; then
  fail "HEAD commit should touch exactly 1 file; got $HEAD_FILE_COUNT: $HEAD_FILES"
fi

if ! printf '%s\n' "$HEAD_FILES" | grep -qF "$PLAN_REL"; then
  fail "HEAD commit should touch $PLAN_REL; got: $HEAD_FILES"
fi

pass "HEAD commit touches exactly 1 file: $PLAN_REL"

# --- Assertion 2: noise.txt remains staged in the index post-commit ----------

STAGED_AFTER="$(git -C "$TMPREPO" diff --cached --name-only)"

info "staged after commit: $STAGED_AFTER"

if ! printf '%s\n' "$STAGED_AFTER" | grep -q "noise.txt"; then
  fail "noise.txt should remain staged after the signing commit; index: $STAGED_AFTER"
fi

pass "noise.txt remains staged (concurrent work preserved)"

# --- Assertion 3: signature field present in plan frontmatter ----------------

if ! grep -q "^orianna_signature_approved:" "$PLAN_FILE"; then
  fail "orianna_signature_approved not found in plan frontmatter after signing"
fi

pass "orianna_signature_approved present in frontmatter"

# --- Assertion 4: T5 auto-derive — STAGED_SCOPE unset produces same commit shape
# Run a second plan with NO STAGED_SCOPE in env; commit must still be scoped
# to exactly the plan file (auto-derive applies PLAN_REL as default).
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T5

PLAN2_FILE="$PLAN_DIR/2026-04-22-staged-scope-auto-derive-plan.md"
cat > "$PLAN2_FILE" <<'PLAN2EOF'
---
status: proposed
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
---

# Auto-derive STAGED_SCOPE test plan

Minimal plan for testing STAGED_SCOPE auto-derive (T5).
PLAN2EOF
git -C "$TMPREPO" add "$PLAN2_FILE"
git -C "$TMPREPO" commit -q -m "chore: seed auto-derive test plan"
PLAN2_REL="plans/proposed/2026-04-22-staged-scope-auto-derive-plan.md"

# Stage another noise file to verify auto-derive scopes the commit correctly
NOISE2_FILE="$TMPREPO/noise2.txt"
printf 'more noise from concurrent session\n' > "$NOISE2_FILE"
git -C "$TMPREPO" add "$NOISE2_FILE"

info "invoking orianna-sign.sh WITHOUT STAGED_SCOPE (T5 auto-derive)"
SIGN2_RC=0
REPO="$TMPREPO" \
  PATH="$TMPBIN:$PATH" \
  bash "$ORIANNA_SIGN" "$PLAN2_FILE" approved 2>&1 || SIGN2_RC=$?

if [ "$SIGN2_RC" -ne 0 ]; then
  fail "auto-derive: orianna-sign.sh exited $SIGN2_RC (expected 0)"
fi

HEAD2_FILES="$(git -C "$TMPREPO" show --name-only --format='' HEAD)"
HEAD2_COUNT="$(printf '%s\n' "$HEAD2_FILES" | grep -c '[^[:space:]]' || echo 0)"

if [ "$HEAD2_COUNT" -ne 1 ]; then
  fail "auto-derive: HEAD commit should touch exactly 1 file; got $HEAD2_COUNT: $HEAD2_FILES"
fi
if ! printf '%s\n' "$HEAD2_FILES" | grep -qF "$PLAN2_REL"; then
  fail "auto-derive: HEAD commit should touch $PLAN2_REL; got: $HEAD2_FILES"
fi
pass "T5 auto-derive: HEAD commit touches exactly 1 file: $PLAN2_REL"

STAGED2_AFTER="$(git -C "$TMPREPO" diff --cached --name-only)"
if ! printf '%s\n' "$STAGED2_AFTER" | grep -q "noise2.txt"; then
  fail "T5 auto-derive: noise2.txt should remain staged after signing commit; index: $STAGED2_AFTER"
fi
pass "T5 auto-derive: noise2.txt remains staged (concurrent work preserved)"

printf '\n[ALL PASS] STAGED_SCOPE test passed (including T5 auto-derive).\n'
exit 0
