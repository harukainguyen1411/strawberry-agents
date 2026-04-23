#!/bin/sh
# test-orianna-gate-inv4-inv5.sh — xfail tests for plan Test plan invariants #4 and #5.
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §Test plan
#
# Invariant #4 — T3 sweep idempotence: running the sweep logic twice against a
#   fixture tree must produce zero diff on the second run.
# Invariant #5 — Lifecycle smoke: a real git commit by Orianna identity with the
#   Promoted-By: Orianna trailer must be accepted by the commit-msg hook;
#   pre-commit hook must also pass when identity + staged paths are correct.
#
# xfail guard: INV-5 requires the commit-msg hook split (fix C1) to exist.
# Until commit-msg-plan-promote-guard.sh is present, INV-5 is xfail.
# INV-4 becomes active immediately (sweep logic is in-tree already).
#
# Run: bash scripts/hooks/test-orianna-gate-inv4-inv5.sh
# Exits 0 if all tests pass or all pending tests are xfail.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_MSG_HOOK="$SCRIPT_DIR/commit-msg-plan-promote-guard.sh"
PRE_COMMIT_HOOK="$SCRIPT_DIR/pre-commit-plan-promote-guard.sh"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"
ORIANNA_EMAIL="orianna@strawberry.local"

PASS=0
FAIL=0
XFAIL=0

report() {
  status="$1"; label="$2"; detail="${3:-}"
  printf '%s  %s\n' "$status" "$label"
  [ -n "$detail" ] && printf '      %s\n' "$detail"
}

# ---- INV-4: sweep idempotence -----------------------------------------------
# Apply strip logic (equivalent to T3 sweep) to a fixture file twice.
# The fixture contains orianna_gate_version and Orianna-Signature blocks.
# After the first run the file should be clean; after the second run the diff
# against the first-run output should be empty.

label="INV-4: T3 sweep idempotence — second run produces zero diff"

TMPDIR_INV4="$(mktemp -d)"
FIXTURE="$TMPDIR_INV4/fixture.md"

# Build a plan file that contains both artefacts the T3 sweep removes:
# 1. orianna_gate_version: 2  frontmatter line
# 2. orianna_signature_* frontmatter fields
# 3. An ## Orianna signature block in the body
cat > "$FIXTURE" <<'FIXTURE_EOF'
---
status: approved
title: fixture plan
owner: tester
concern: personal
created: 2026-04-22
tests_required: false
orianna_gate_version: 2
orianna_signature_hash: abc123
orianna_signature_date: 2026-04-22
---

# Fixture Plan

Some content here.

## Orianna signature

Approved by Orianna on 2026-04-22. Transition: proposed → approved.

## Next steps

More content.
FIXTURE_EOF

# Sweep function: mirrors what T3 did — strip orianna_gate_version, orianna_signature_*
# frontmatter keys and the ## Orianna signature block.
run_sweep() {
  _f="$1"
  # Strip orianna_gate_version and orianna_signature_* frontmatter lines (sed -i variant)
  # Use tmp file to avoid sed -i portability differences.
  _tmp="$(mktemp)"
  # Remove orianna_gate_version: ... and orianna_signature_*: ... lines
  grep -v '^orianna_gate_version:' "$_f" | grep -v '^orianna_signature_' > "$_tmp"
  mv "$_tmp" "$_f"
  # Remove ## Orianna signature blocks (block from ## Orianna signature up to next ## or EOF)
  _tmp2="$(mktemp)"
  awk '
    /^## Orianna signature/ { skip=1; next }
    skip && /^## / { skip=0 }
    !skip { print }
  ' "$_f" > "$_tmp2"
  mv "$_tmp2" "$_f"
}

cp "$FIXTURE" "$TMPDIR_INV4/before.md"
run_sweep "$FIXTURE"
cp "$FIXTURE" "$TMPDIR_INV4/after_run1.md"
run_sweep "$FIXTURE"
cp "$FIXTURE" "$TMPDIR_INV4/after_run2.md"

# Second run should produce zero diff relative to first run
if diff -q "$TMPDIR_INV4/after_run1.md" "$TMPDIR_INV4/after_run2.md" > /dev/null 2>&1; then
  report PASS "$label"
  PASS=$((PASS + 1))
else
  report FAIL "$label — second sweep changed the file"
  diff "$TMPDIR_INV4/after_run1.md" "$TMPDIR_INV4/after_run2.md" | head -20
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR_INV4"

# ---- INV-5: lifecycle smoke --------------------------------------------------
# End-to-end: real git commit by Orianna identity with Promoted-By: Orianna trailer.
# Requires: commit-msg-plan-promote-guard.sh (fix C1) AND _orianna_identity.txt present.

label="INV-5: lifecycle smoke — Orianna commit accepted by commit-msg hook"

if [ ! -f "$COMMIT_MSG_HOOK" ]; then
  report XFAIL "$label — commit-msg-plan-promote-guard.sh not yet created (fix C1 pending)"
  XFAIL=$((XFAIL + 1))
elif [ ! -f "$IDENTITY_FILE" ]; then
  report XFAIL "$label — identity file missing"
  XFAIL=$((XFAIL + 1))
else
  # Build a sandbox git repo and run a real commit
  TMPDIR_INV5="$(mktemp -d)"
  git -C "$TMPDIR_INV5" init -q
  git -C "$TMPDIR_INV5" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$TMPDIR_INV5/plans/proposed/personal" "$TMPDIR_INV5/plans/approved/personal"
  printf -- '---\nstatus: proposed\ntitle: smoke-test\nowner: orianna\n---\n\n# Smoke\n' \
    > "$TMPDIR_INV5/plans/proposed/personal/smoke.md"
  git -C "$TMPDIR_INV5" add plans/
  git -C "$TMPDIR_INV5" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add proposed plan"
  mkdir -p "$TMPDIR_INV5/scripts/hooks"
  cp "$IDENTITY_FILE" "$TMPDIR_INV5/scripts/hooks/_orianna_identity.txt"
  # Install the commit-msg hook
  cp "$COMMIT_MSG_HOOK" "$TMPDIR_INV5/.git/hooks/commit-msg"
  chmod +x "$TMPDIR_INV5/.git/hooks/commit-msg"
  # Install the pre-commit hook
  cp "$PRE_COMMIT_HOOK" "$TMPDIR_INV5/.git/hooks/pre-commit"
  chmod +x "$TMPDIR_INV5/.git/hooks/pre-commit"

  # Stage a rename from proposed to approved
  git -C "$TMPDIR_INV5" mv \
    plans/proposed/personal/smoke.md \
    plans/approved/personal/smoke.md

  # Commit as Orianna with the required trailer
  COMMIT_MSG="chore: promote smoke plan to approved

Promoted-By: Orianna
Rationale: lifecycle smoke test"

  rc=0
  commit_output="$(
    GIT_AUTHOR_EMAIL="$ORIANNA_EMAIL" \
    GIT_COMMITTER_EMAIL="$ORIANNA_EMAIL" \
    git -C "$TMPDIR_INV5" \
      -c user.email="$ORIANNA_EMAIL" \
      -c user.name="Orianna" \
      commit -m "$COMMIT_MSG" 2>&1
  )" || rc=$?

  rm -rf "$TMPDIR_INV5"

  if [ "$rc" -eq 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label — commit exited $rc"
    printf '      %s\n' "$commit_output"
    FAIL=$((FAIL + 1))
  fi
fi

# ---- summary ----------------------------------------------------------------
printf '\nResults: %d passed, %d failed, %d xfail\n' "$PASS" "$FAIL" "$XFAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
