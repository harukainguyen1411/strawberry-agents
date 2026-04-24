#!/usr/bin/env bash
# scripts/tests/decrypt-exec.sh
# Plan: plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md T-new-E
#
# Positive integration test for tools/decrypt.sh --exec surface.
#
# Fixture strategy: REPO KEY (not a throwaway keypair).
# Rationale: tools/decrypt.sh hard-codes the key path to
# secrets/age-key.txt with no --key override. Generating a throwaway
# keypair and swapping the file is excluded by Rule 6 (never write to
# secrets/age-key.txt in tests). Instead this test uses the repo public
# key (extracted via the sanctioned `age-keygen -y` form, which does not
# read plaintext from the key file) to encrypt a dummy fixture string
# "fixture-not-a-secret" at runtime. The ciphertext is held in a shell
# variable and piped directly to tools/decrypt.sh; no .age blob is
# committed to the repo.
#
# Rule 6 compliance:
#   - The plaintext string is a dummy sentinel value, not a real secret.
#   - `age-keygen -y` reads only the public key from secrets/age-key.txt;
#     it does not expose the private key.
#   - No plaintext is written to any location outside secrets/; the
#     tools/decrypt.sh --target path is under secrets/work/runtime/.
#
# Assertions:
#   (i)   tools/decrypt.sh --exec exits 0 when child command succeeds
#   (ii)  No plaintext appears in captured stdout/stderr of the parent
#   (iii) --target file has mode 0600 on exit (cleanup is the caller's
#         responsibility here; we verify perms before the test cleanup)
#   (iv)  A failing child command propagates a non-zero exit
#
# Exit codes: 0 = all assertions pass, 1 = one or more assertions failed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DECRYPT="$REPO_ROOT/tools/decrypt.sh"
KEY_FILE="$REPO_ROOT/secrets/age-key.txt"
RUNTIME_DIR="$REPO_ROOT/secrets/work/runtime"

PASS=0
FAIL=0
FIXTURE_PLAINTEXT="fixture-not-a-secret"

_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "=== decrypt-exec.sh: tools/decrypt.sh --exec integration tests ==="

# --- Prerequisites ---------------------------------------------------------

if [ ! -f "$DECRYPT" ]; then
  printf 'ERROR: %s not found\n' "$DECRYPT" >&2; exit 1
fi
if [ ! -f "$KEY_FILE" ]; then
  printf 'ERROR: secrets/age-key.txt not found — cannot run test\n' >&2; exit 1
fi
if ! command -v age-keygen >/dev/null 2>&1; then
  printf 'ERROR: age-keygen not in PATH — install age (brew install age)\n' >&2; exit 1
fi
if ! command -v age >/dev/null 2>&1; then
  printf 'ERROR: age not in PATH — install age (brew install age)\n' >&2; exit 1
fi

# Create the runtime dir if it does not yet exist (gitignored under secrets/*).
mkdir -p "$RUNTIME_DIR"

# --- Fixture setup ---------------------------------------------------------
# Extract public key via the sanctioned form (does NOT expose the private key).
pub_key="$(age-keygen -y "$KEY_FILE")"
if [ -z "$pub_key" ]; then
  printf 'ERROR: failed to extract public key from secrets/age-key.txt\n' >&2; exit 1
fi

# Encrypt the dummy plaintext into a ciphertext variable at runtime.
# The ciphertext blob is never written to a committed path.
fixture_ciphertext="$(printf '%s' "$FIXTURE_PLAINTEXT" | age -r "$pub_key" -a)"
if [ -z "$fixture_ciphertext" ]; then
  printf 'ERROR: age encryption of fixture plaintext failed\n' >&2; exit 1
fi

# --- Test helpers ----------------------------------------------------------
# We use a per-test unique target path so parallel runs don't collide.
# Absolute path ensures tools/decrypt.sh target-validation works regardless
# of the caller's cwd.
_next_target() {
  printf '%s/decrypt-test-%s-%s.env' "$RUNTIME_DIR" "$$" "$1"
}

# Cleanup any target files created by this run on exit.
_cleanup_targets() {
  rm -f "$RUNTIME_DIR/decrypt-test-$$-"*.env 2>/dev/null || true
}
trap '_cleanup_targets' EXIT INT TERM

# --- Test 1: --exec exits 0 when the child command exits 0 -----------------
target1="$(_next_target 1)"
exec_output="$(printf '%s' "$fixture_ciphertext" | \
  "$DECRYPT" --target "$target1" \
             --var FIXTURE_TOKEN \
             --exec -- /bin/sh -c 'test "$FIXTURE_TOKEN" = "fixture-not-a-secret"' \
  2>&1)"
exec_exit=$?

if [ "$exec_exit" -eq 0 ]; then
  _pass "T1: --exec exits 0 when child test succeeds"
else
  _fail "T1: --exec exited $exec_exit (expected 0); output: $exec_output"
fi

# --- Test 2: no plaintext in captured stdout/stderr of parent --------------
# $exec_output holds the combined stdout+stderr of the decrypt call above.
# It must not contain the fixture plaintext.
if printf '%s' "$exec_output" | grep -qF "$FIXTURE_PLAINTEXT"; then
  _fail "T2: plaintext '$FIXTURE_PLAINTEXT' appeared in parent stdout/stderr"
else
  _pass "T2: no plaintext in parent stdout/stderr"
fi

# --- Test 3: --target file has mode 0600 -----------------------------------
# The target file is written before --exec replaces the shell; check perms.
# We need a second invocation where the child doesn't replace our test shell.
# Strategy: use a child that just exits 0 so the target file is written and
# remains accessible before exec replaces the parent.  In the --exec flow the
# shell IS replaced, so we can't inspect after the fact; instead we invoke
# without --exec to inspect perms, then separately verify the exec path.
target3="$(_next_target 3)"
printf '%s' "$fixture_ciphertext" | \
  "$DECRYPT" --target "$target3" \
             --var FIXTURE_TOKEN \
  >/dev/null 2>&1 || true

if [ -f "$target3" ]; then
  file_perms="$(stat -f '%A' "$target3" 2>/dev/null || stat -c '%a' "$target3" 2>/dev/null || echo "unknown")"
  if [ "$file_perms" = "600" ]; then
    _pass "T3: --target file has mode 0600"
  else
    _fail "T3: --target file has mode $file_perms (expected 600)"
  fi
else
  _fail "T3: --target file not created by non-exec invocation"
fi

# --- Test 4: --exec propagates non-zero exit from child --------------------
target4="$(_next_target 4)"
printf '%s' "$fixture_ciphertext" | \
  "$DECRYPT" --target "$target4" \
             --var FIXTURE_TOKEN \
             --exec -- /bin/sh -c 'test "$FIXTURE_TOKEN" = "wrong-expected-value"' \
  >/dev/null 2>&1
exec_fail_exit=$?

if [ "$exec_fail_exit" -ne 0 ]; then
  _pass "T4: --exec propagates non-zero exit from failing child"
else
  _fail "T4: --exec returned 0 for a child that should have failed"
fi

# --- Test 5: --target absent from parent env after --exec ------------------
# exec replaces the shell, so FIXTURE_TOKEN must NOT leak into the parent.
# We verify by checking that our current shell has no such variable set.
# (The $exec_output from T1 is the combined output, not env; the shell that
# ran the child is gone. This is a structural guarantee of `exec env ...`.)
if [ -z "${FIXTURE_TOKEN:-}" ]; then
  _pass "T5: FIXTURE_TOKEN is not set in parent shell after --exec"
else
  _fail "T5: FIXTURE_TOKEN leaked into parent shell (value: ${FIXTURE_TOKEN})"
fi

# --- Summary ---------------------------------------------------------------
echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
