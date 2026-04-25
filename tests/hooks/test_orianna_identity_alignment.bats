#!/usr/bin/env bash
# tests/hooks/test_orianna_identity_alignment.bats
#
# Regression test: Orianna single-pass clean promotion.
#
# Plan: plans/approved/personal/2026-04-25-orianna-identity-protocol-alignment.md
# T1: xfail fixture — proves that with the OLD git-identity.sh (persona identity),
#     a commit+push simulation in a single pass (no --amend) fails at Layer 3
#     (pre-push-resolved-identity.sh). After T2 updates git-identity.sh to neutral
#     identity, the same flow passes.
#
# xfail: XFAIL=1 means we currently expect the push to be BLOCKED.
#        After T2 lands, set XFAIL=0 and remove this comment block.
#
# What is tested:
#   1. A temp git repo is initialised with neutral identity.
#   2. agents/orianna/memory/git-identity.sh is sourced (sets author identity).
#   3. A plan-promotion commit is made with "Promoted-By: Orianna" trailer.
#   4. The pre-push hook is invoked directly with the correct stdin format.
#   5. Assert: commit exit 0 AND push hook exit 0 (no block) = single-pass clean.
#
# Invariants verified:
#   - Single-pass clean promotion (no amend-shuffle needed)
#   - Promoted-By: Orianna trailer survives in commit body
#   - Layer 3 (pre-push-resolved-identity.sh) is the unmodified live hook
#
# Note on test harness: git push is NOT used directly because `core.hooksPath`
# in the test environment points to the global dispatcher, which resolves
# REPO_ROOT via git rev-parse inside the temp repo (finds no scripts/hooks/).
# Instead, the pre-push hook is invoked directly with the push-protocol stdin,
# which is equivalent and exercises the same code path.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

IDENTITY_SCRIPT="$REPO_ROOT/agents/orianna/memory/git-identity.sh"
PREPUSH_HOOK="$REPO_ROOT/scripts/hooks/pre-push-resolved-identity.sh"
ZERO_SHA="0000000000000000000000000000000000000000"

# xfail flag: 1 = push expected to be BLOCKED (old persona identity); 0 = must pass
XFAIL=1

pass=0
fail=0
skip=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.name "Duongntd"
  git -C "$dir" config user.email "103487096+Duongntd@users.noreply.github.com"
  git -C "$dir" commit --allow-empty -q -m "chore: init"
  printf '%s' "$dir"
}

run_orianna_promotion_flow() {
  # Returns 0 if single-pass commit + hook-push succeeds, 1 if either is blocked.
  local repo="$1"

  # Source git-identity.sh to simulate Orianna's startup in the repo
  (
    cd "$repo" || exit 1
    bash "$IDENTITY_SCRIPT" 2>/dev/null
  )

  # Make a plan-promotion commit (no --amend — the invariant)
  git -C "$repo" commit --allow-empty -q \
    -m "chore: promote 2026-04-25-orianna-identity-protocol-alignment to approved" \
    -m "Promoted-By: Orianna" 2>/dev/null
  local commit_exit=$?

  if [ "$commit_exit" -ne 0 ]; then
    printf 'commit-failed\n' >&2
    return 1
  fi

  local sha
  sha="$(git -C "$repo" rev-parse HEAD)"

  # Verify trailer exists in commit body
  if ! git -C "$repo" cat-file commit "$sha" | grep -q 'Promoted-By: Orianna'; then
    printf 'trailer-missing\n' >&2
    return 1
  fi

  # Invoke the pre-push hook directly against the repo (simulates git push to remote)
  # stdin format: <local-ref> <local-sha> <remote-ref> <remote-sha>
  # remote-sha = ZERO_SHA (new branch / first push of this commit)
  # Must run from inside the repo so git rev-list resolves correctly.
  local hook_out hook_exit
  hook_out="$(cd "$repo" && printf 'refs/heads/main %s refs/heads/main %s\n' \
    "$sha" "$ZERO_SHA" | bash "$PREPUSH_HOOK" origin 2>&1)"
  hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'push-blocked: %s\n' "$hook_out" >&2
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Test case
# ---------------------------------------------------------------------------

run_case() {
  local desc="$1"

  if [ ! -f "$PREPUSH_HOOK" ]; then
    printf 'XFAIL (hook absent): %s\n' "$desc"
    skip=$((skip + 1))
    return
  fi

  if [ ! -f "$IDENTITY_SCRIPT" ]; then
    printf 'XFAIL (identity script absent): %s\n' "$desc"
    skip=$((skip + 1))
    return
  fi

  local repo
  repo="$(make_repo)"

  local actual_pass=0
  run_orianna_promotion_flow "$repo" 2>/dev/null || actual_pass=1

  rm -rf "$repo"

  if [ "$XFAIL" -eq 1 ]; then
    # We EXPECT the push hook to BLOCK (actual_pass=1) until T2 lands
    if [ "$actual_pass" -ne 0 ]; then
      printf 'XFAIL (expected — Layer 3 blocks persona identity before T2): %s\n' "$desc"
      skip=$((skip + 1))
    else
      # Flow succeeded while xfail=1 — drift: T2 may have landed but marker not removed
      printf 'FAIL (xfail=1 but flow succeeded — T2 landed without removing XFAIL marker?): %s\n' \
        "$desc" >&2
      fail=$((fail + 1))
    fi
  else
    # xfail removed: T2 is in place; single-pass flow MUST succeed
    if [ "$actual_pass" -eq 0 ]; then
      printf 'PASS: %s\n' "$desc"
      pass=$((pass + 1))
    else
      printf 'FAIL (single-pass blocked — T2 may not have applied correctly): %s\n' "$desc" >&2
      fail=$((fail + 1))
    fi
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_case "Orianna single-pass clean promotion: commit+push succeeds without amend"

printf '\nResults: pass=%d fail=%d skip=%d\n' "$pass" "$fail" "$skip"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
