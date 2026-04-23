#!/usr/bin/env bash
# test-orianna-sign-prefix-restore.sh — xfail test for T2 snapshot/restore contract.
#
# Plan: plans/in-progress/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md T1/T2
#
# CONTRACT: when orianna-sign.sh invokes a pre-fix pass and claude returns
# block_findings > 0, the plan file on disk MUST be byte-identical to its
# pre-sign state. Rule 1 — no uncommitted mutations left in the tree after a
# refused sign.
#
# xfail: this test FAILS on the current main (pre-T2) because orianna-sign.sh
# does not yet restore the plan after a block-findings claude response when
# pre-fix is active. It will pass after T2 implements snapshot/restore.
#
# Usage: bash scripts/hooks/tests/test-orianna-sign-prefix-restore.sh
# Exit 0 — pass (plan unchanged after block), 1 — fail, 2 — setup error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ORIANNA_SIGN="$REPO_ROOT/scripts/orianna-sign.sh"
ORIANNA_PRE_FIX="$REPO_ROOT/scripts/orianna-pre-fix.sh"

pass() { printf '[test-prefix-restore] PASS: %s\n' "$*"; }
fail() { printf '[test-prefix-restore] FAIL: %s\n' "$*" >&2; exit 1; }
info() { printf '[test-prefix-restore] INFO: %s\n' "$*"; }

# ---- Setup temp repo --------------------------------------------------------

TMPDIR_REPO="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_REPO"' EXIT

info "temp repo: $TMPDIR_REPO"

git init -q "$TMPDIR_REPO"
git -C "$TMPDIR_REPO" config user.email "test@test.local"
git -C "$TMPDIR_REPO" config user.name "Test"

# Seed with an initial commit so the repo is non-empty
git -C "$TMPDIR_REPO" commit --allow-empty -q -m "init"

# Create minimal required structure
mkdir -p "$TMPDIR_REPO/plans/proposed/work"
mkdir -p "$TMPDIR_REPO/assessments/plan-fact-checks"
mkdir -p "$TMPDIR_REPO/scripts/hooks/tests"
mkdir -p "$TMPDIR_REPO/agents/orianna/prompts"

# Copy scripts into temp repo
cp "$REPO_ROOT/scripts/orianna-sign.sh"        "$TMPDIR_REPO/scripts/"
cp "$REPO_ROOT/scripts/orianna-hash-body.sh"   "$TMPDIR_REPO/scripts/"
cp "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPDIR_REPO/scripts/" 2>/dev/null || true
[ -f "$REPO_ROOT/scripts/orianna-pre-fix.sh" ] && cp "$REPO_ROOT/scripts/orianna-pre-fix.sh" "$TMPDIR_REPO/scripts/"
[ -f "$REPO_ROOT/scripts/_lib_stale_lock.sh" ] && cp "$REPO_ROOT/scripts/_lib_stale_lock.sh" "$TMPDIR_REPO/scripts/"
[ -f "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" ] && cp "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" "$TMPDIR_REPO/scripts/"

# Minimal prompt file so orianna-sign.sh doesn't die before we reach the
# claude invocation (we stub claude below).
printf '# gate check prompt\n' > "$TMPDIR_REPO/agents/orianna/prompts/plan-check.md"

# ---- Create a test plan with pre-fix-eligible content ----------------------
# Use concern: work so that auto-detect enables the pre-fix pass.

PLAN_PATH="$TMPDIR_REPO/plans/proposed/work/test-prefix-restore-plan.md"
cat > "$PLAN_PATH" <<'PLANEOF'
---
status: proposed
concern: work
owner: test
created: 2026-04-22
orianna_gate_version: 2
tests_required: false
---

# Test plan for prefix-restore contract

## Tasks

### T1. Example task
- estimate_minutes: 5

## Test plan

No tests required.
PLANEOF

ORIGINAL_CONTENT="$(cat "$PLAN_PATH")"
info "plan created: $PLAN_PATH"

# Commit the plan so git add in orianna-sign.sh has a tracked file to work with
git -C "$TMPDIR_REPO" add "$PLAN_PATH"
git -C "$TMPDIR_REPO" commit -q -m "chore: test plan"

# ---- Stub `claude` to return exit 1 (block) --------------------------------
# Place a stub on PATH that writes a report with block_findings: 1 and exits 1.

STUB_BIN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_REPO" "$STUB_BIN"' EXIT

cat > "$STUB_BIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
# Stub claude: writes a block-findings report and exits 1.
REPORT_DIR=""
# Find --system-prompt arg to locate REPO (unused here; we derive from cwd)
# orianna-sign.sh creates $REPORT_DIR via mkdir -p then passes FULL_PROMPT to us.
# We write the report to any assessments/plan-fact-checks/ dir we can find.
for arg in "$@"; do
  case "$arg" in
    *assessments*) ;;
  esac
done
# Locate the repo root from REPO env or from the plan path in the prompt
REPO="${REPO:-}"
if [ -n "$REPO" ] && [ -d "$REPO" ]; then
  REPORT_OUT="$REPO/assessments/plan-fact-checks"
else
  # Fallback: derive from script dir (won't be reached normally)
  REPORT_OUT="/tmp/orianna-report-stub-$$"
fi
mkdir -p "$REPORT_OUT"
REPORT_FILE="$REPORT_OUT/test-prefix-restore-plan-$(date -u +%Y%m%dT%H%M%SZ).md"
cat > "$REPORT_FILE" <<EOF
---
block_findings: 1
---
# Block report (stub)
Finding: stub claude returning block for xfail test.
EOF
exit 1
STUBEOF
chmod +x "$STUB_BIN/claude"

# ---- Also stub orianna-pre-fix.sh to mutate the plan -----------------------
# This simulates a pre-fix pass that changes the plan body. If snapshot/restore
# is not implemented, the mutation will survive the block and cause a diff.

PRE_FIX_STUB="$TMPDIR_REPO/scripts/orianna-pre-fix.sh"
cat > "$PRE_FIX_STUB" <<'PREFIXEOF'
#!/usr/bin/env bash
# Stub pre-fix: appends a whitespace change to simulate a body rewrite.
PLAN="$1"
printf '\n<!-- pre-fix stub mutation -->\n' >> "$PLAN"
printf 'pre-fix-stub-change\n'
PREFIXEOF
chmod +x "$PRE_FIX_STUB"

# ---- Run orianna-sign.sh with stubbed claude --------------------------------

info "running orianna-sign.sh with block-returning claude stub..."

REPO="$TMPDIR_REPO" PATH="$STUB_BIN:$PATH" \
  bash "$TMPDIR_REPO/scripts/orianna-sign.sh" \
  --pre-fix \
  "plans/proposed/work/test-prefix-restore-plan.md" \
  approved 2>/dev/null || sign_exit=$?

sign_exit="${sign_exit:-0}"
info "orianna-sign.sh exit: $sign_exit"

# ---- Assert plan is byte-identical to pre-sign state -----------------------

CURRENT_CONTENT="$(cat "$PLAN_PATH")"

if [ "$CURRENT_CONTENT" = "$ORIGINAL_CONTENT" ]; then
  pass "plan is byte-identical after block-findings exit — snapshot/restore working"
  exit 0
else
  fail "plan was mutated by pre-fix and NOT restored after block-findings. Rule 1 violated.
Expected content (original):
$ORIGINAL_CONTENT

Actual content (post-sign):
$CURRENT_CONTENT"
fi
