# Parallel agent staging contamination during orianna-sign.sh

## Date
2026-04-21

## Summary
When multiple agent sessions run concurrently in the same repo, `orianna-sign.sh` is vulnerable to staging-area contamination during the `claude -p` gate-check invocation (~20s).

## Root cause
`orianna-sign.sh` runs `claude -p --dangerously-skip-permissions` for the gate check, then calls `git add <plan>` + `git commit`. The `--dangerously-skip-permissions` mode allows the Orianna agent to write files and stage them (via its own bash tool calls). Parallel sessions also write and stage files at any moment. Between the `git add` step and `git commit`, contaminating files may be in the index.

## Failure modes observed

1. **Multi-file signing commit**: Sign commit includes the plan + 1-2 unrelated files staged by parallel sessions. Caught by `orianna-verify-signature.sh` at promotion time with "signing commit touches N files (must touch exactly 1)".

2. **git index.lock contention**: Parallel session holds the index lock when sign tries to commit. Exit code 128. Plan file has signature written in working tree but not committed.

3. **Empty commit**: Parallel session overwrites the plan file (removing the freshly-appended signature) between sign's `git add` and `git commit`. Empty commit results. Plan file reverts to pre-signature state.

## Mitigations

- Check `git status --short | grep "^[MADRC]"` and reset all staged files to clean before each sign attempt.
- Run sign attempts when parallel activity is lowest (between agent session boundaries).
- If sign produces an empty or multi-file commit, detect by checking `git show <SHA> --name-status` immediately after the sign. If contaminated, remove stale signature from plan and retry.

## Fix (pending)
orianna-gate-speedups plan T7 (stale-lock helper) and T5 (shape-B atomic commit) would address the lock-contention failure. A more robust fix would be: after `git add <plan>`, check that only the plan file is staged (reset any others), then commit.

## Key path
`scripts/orianna-sign.sh` — lines 288-306 (git add + commit section)

## Related plans
`plans/approved/personal/2026-04-21-orianna-gate-speedups.md`
