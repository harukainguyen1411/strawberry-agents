# 2026-04-23 — PR #30 Orianna v2: pre-commit hook reading stale COMMIT_EDITMSG

## Context

Reviewed `orianna-gate-simplification` (v2 hook replaces v1 8-script signing
regime with identity + trailer check). Test suites pass 6/6 on both
`test-orianna-gate-v2.sh` and `test-plan-promote-guard.sh`. Plan explicitly
called out the design fork: _"Read the commit message from `$1` in the
commit-msg hook, or use a two-stage check where pre-commit validates author +
staged paths and commit-msg validates trailer"_ (§T4 line 62).

Implementation chose single-stage pre-commit. Ships broken.

## Verdict

REQUEST_CHANGES. Critical functional bug: Orianna cannot commit a promotion
in production because pre-commit hooks cannot read the incoming commit
message — `.git/COMMIT_EDITMSG` at pre-commit time contains the **previous**
commit's message (or is missing). Git only writes the new message to that
file AFTER pre-commit passes.

## How the tests missed it

Both test suites manually write `.git/COMMIT_EDITMSG` before invoking the
hook, then call `bash $HOOK` directly:

```sh
if [ -n "$msg" ]; then
  printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
fi
GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" GIT_AUTHOR_EMAIL="$email" bash "$HOOK"
```

This is a test harness bug: it simulates a state (post-commit-msg) that git
never actually produces at pre-commit time. The hook passes unit tests and
fails in reality. The fix for future tests: invoke a real `git commit`
through a full fixture repo with the hook installed at `.git/hooks/pre-commit`
(mimicking what `install-hooks.sh` does) — that's what
`test-commit-msg-no-ai-coauthor.sh` does, and it's the correct pattern for
any hook whose behavior depends on git plumbing state.

## Detection technique

The direct-invocation edge-probe matrix (15 probes) passed 14/14 because it
also pre-wrote EDITMSG. The bug only surfaced when I mimicked a **real** git
commit flow with `core.hooksPath` overridden (because Duong's global config
has `/Users/duongntd99/.config/git/hooks` which was suppressing my local
hooks — caught that because my first trace-hook didn't produce any log
output).

**Lesson:** always test hooks through `git commit`, not through direct shell
invocation. If the hook's contract involves git-plumbing state
(COMMIT_EDITMSG, commit-msg $1 arg, MERGE_MSG, etc.), direct invocation
cannot exercise the contract.

**Lesson 2:** before concluding "local hook not firing," check
`git config --get core.hooksPath` at both local and global level. Ours is
set globally to `~/.config/git/hooks`, which silently takes precedence over
`.git/hooks/pre-commit` unless overridden per-repo.

## The second-order finding: forgery detection is decoupled from threat

Even if you ignore the "trailer never triggers for Orianna" bug, the
forgery-detection path (`has_promoted_by_trailer && !is_orianna && !is_admin
→ BLOCK`) is operating on stale data. It can only fire when the *previous*
commit's EDITMSG happened to contain `Promoted-By: Orianna`. Whether the
attacker's actual commit message has the trailer is irrelevant. The defense
only holds because the fallback branch ("unauthorized plan promotion")
catches generic authors without trailers — which is coincidentally the
realistic attack vector.

## Missing invariant tests

Plan enumerates 6 invariants. Tests cover 4:
- INV-1 ✓ (non-Orianna rejected)
- INV-2 ✓ (Orianna + trailer accepted — BUT this "passes" only because
  of the harness bug; real flow blocks)
- INV-3 ✓ (forgery blocked — but same harness-bug caveat)
- INV-4 SWEEP IDEMPOTENCE — no test
- INV-5 LIFECYCLE SMOKE — no test (end-to-end Orianna agent invocation,
  hard to automate but a simulated-commit version would have caught C1)
- INV-6 ✓ (admin-only path protection)

The sweep-idempotence gap is concerning because T3 (`6255eab`) touches 50
plans, and a re-run without the idempotence guarantee could corrupt any
grandfathered `orianna_gate_version:` fields.

## Empty trigger commit

`64fb866 chore: trigger CI re-run after pr-lint.yml >300-file fix` — zero
diff, no body. Flagged for squash at merge.

## Rule 18 / identity

Preflight `scripts/reviewer-auth.sh --lane senna gh api user --jq .login`
returned `strawberry-reviewers-2`. Review submitted under that identity.
PR author was `duongntd99` — no Rule 18 conflict.

## Review URL

CHANGES_REQUESTED submitted 2026-04-23T04:46:33Z by `strawberry-reviewers-2`.
