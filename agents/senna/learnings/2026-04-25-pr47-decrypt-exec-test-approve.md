---
date: 2026-04-25
topic: PR47 decrypt-exec integration test (T-new-E) — APPROVE
pr: 47
verdict: APPROVE (advisory)
---

# PR #47 — decrypt-exec integration test + pre-commit gate

## Summary

Code-quality + security review of T-new-E (Sona-secretary-MCP-suite ADR). Author Syndra delivered a clean, well-documented positive integration test for `tools/decrypt.sh --exec`, plus a pre-commit hook that gates `tools/decrypt.sh` refactors on the test passing. Verdict: APPROVE; no merge-blocking findings.

## What the PR does

- `scripts/tests/decrypt-exec.sh` (+173) — five assertions T1–T5 against `tools/decrypt.sh --exec`.
- `scripts/hooks/pre-commit-decrypt-exec-test.sh` (+44) — runs the test when `tools/decrypt.sh`, the test, or the hook is staged.
- Fixture strategy: extract repo public key via `age-keygen -y`, encrypt dummy `fixture-not-a-secret` at runtime, pipe ciphertext on stdin. No committed `.age` blob; no real secret material.

## Test isolation

- `secrets/work/runtime/` is gitignored at the repo level — runtime artifacts cannot be accidentally committed.
- Trap on `EXIT INT TERM` clears `decrypt-test-$$-*.env`. PID-suffix avoids parallel collisions.
- Verified locally: 5/5 PASS, no residue after run.

## Key things to check on integration tests for `tools/decrypt.sh`

This is the canonical test pattern for any future refactor of `tools/decrypt.sh`. Future reviews should look for:

1. **Structural `exec`-ness** — current tests verify behavioral surface (exit code, env propagation, perms, no leak). They do NOT verify that `exec` actually replaces the shell. A refactor from `exec env ...` to plain `env ...` would pass all five assertions but degrade the security posture (parent shell holds secret in memory after handoff). Probe via `/bin/sh -c 'echo $PPID'` or PID equality is the cheap fix.
2. **Pub-key extraction safety** — `age-keygen -y "$KEY_FILE"` is the sanctioned form (does not expose private key). Any test that writes to `secrets/age-key.txt` directly is a Rule 6 violation.
3. **Silent-skip-vs-hard-fail asymmetry** — hooks should silently skip when `secrets/age-key.txt` is absent (CI runners); direct test invocations may hard-fail. This asymmetry is intentional but should be documented.
4. **Trap discipline** — `EXIT INT TERM` covers typical cleanup paths but does NOT fire when `--exec` succeeds (shell is replaced). Tests that verify the `--exec` path must do their cleanup before invoking it, OR rely on the OS to clean up the runtime file via gitignored-dir hygiene.

## Suggestion items I posted (non-blocking)

1. T3 masks `decrypt.sh` failures with `|| true` — would lose upstream diagnostic.
2. T5 is structurally tautological — `$(...)` makes parent-shell-leak impossible by construction.
3. Tests verify behavioral surface, not structural `exec`-ness (see above).
4. Hook silent-skip vs test hard-fail divergence on missing key.
5. Plan-path comment will go stale when plan moves out of `approved/`.
6. `pub_key=$(age-keygen -y ...)` doesn't suppress stderr — see `2026-04-18-decrypt-sh-stderr-containment.md`.

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/47#pullrequestreview-PRR_kwDOSGFeXc742XlC

## Identity / process

- Used `scripts/reviewer-auth.sh --lane senna gh pr review …` per Rule 18.
- Verified identity returned `strawberry-reviewers-2` before submitting.
- Lucian (`strawberry-reviewers`) had already approved on plan/ADR fidelity. Both lanes green.
