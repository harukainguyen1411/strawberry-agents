# 2026-04-24 — decrypt-exec test: fixture strategy and target-path constraint

## Context

T-new-E of the Sona secretary MCP suite ADR required a positive test for
`tools/decrypt.sh --exec`. Two non-obvious constraints shaped the fixture strategy.

## Constraint 1: --target must resolve under secrets/

`tools/decrypt.sh` validates the `--target` path against `$REPO_ROOT/secrets/`.
The ADR task description used `/tmp/fixture.env` as the example target — this
would fail the tool's own validation (exit code 5). Canonical runtime path is
`secrets/work/runtime/<name>.env` per ADR §4.2. Always use absolute paths when
calling the tool from a test (the tool's internal `cd` is relative to the path
given, not to REPO_ROOT).

## Constraint 2: throwaway age keypair requires a --key override that doesn't exist

`tools/decrypt.sh` hard-codes `KEY_FILE="$REPO_ROOT/secrets/age-key.txt"` — no
`--key` flag. Generating a throwaway keypair and swapping `secrets/age-key.txt`
is forbidden by Rule 6. Solution: use the repo public key via
`age-keygen -y secrets/age-key.txt` (sanctioned form — reads only the public
half, never exposes the private key) to encrypt a dummy plaintext at test
runtime. The ciphertext lives in a shell variable; no `.age` blob is committed.

## Constraint 3: committed .age fixtures outside secrets/encrypted/ trip Guard 1

The pre-commit secrets guard blocks any file outside `secrets/encrypted/` that
contains `BEGIN AGE ENCRYPTED FILE`. Scripts/tests/fixtures/ is not in the
allowlist. Generating the fixture at runtime avoids this entirely.

## Pre-commit wiring pattern

Added `scripts/hooks/pre-commit-decrypt-exec-test.sh` — the dispatcher runs all
`pre-commit-*.sh` scripts alphabetically. Hook skips silently when
`secrets/age-key.txt` is absent (CI / keyless machines) so it doesn't block
non-key environments. Triggers only on staged changes to `tools/decrypt.sh`,
the test itself, or the hook itself.

## Test convention

Existing tests in `scripts/tests/` are POSIX bash `.sh` (not bats, despite bats
being on PATH). Follow the same convention. Exit 0 = pass, non-zero = fail.
Use `printf 'PASS: ...'` / `printf 'FAIL: ...'` pattern.
