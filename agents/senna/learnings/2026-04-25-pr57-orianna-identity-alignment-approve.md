# PR #57 — Orianna identity protocol alignment — APPROVE

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#57
**Branch:** orianna-identity-alignment
**Verdict:** APPROVE (Senna lane, strawberry-reviewers-2)
**Lucian also approved** earlier from strawberry-reviewers (fidelity lane).

## What the PR did

Flipped `agents/orianna/memory/git-identity.sh` to set neutral `Duongntd` identity instead of persona `orianna@strawberry.local`. Persona signal moved exclusively into `Promoted-By: Orianna` commit body trailer. Layer 2 carve-out kept as defense-in-depth. Eliminates the `git commit --amend` round-trip Orianna previously needed to satisfy Layer 3 (pre-push-resolved-identity.sh has no Orianna carve-out).

## How I verified the test isn't a tautology

The PR's bats fixture `tests/hooks/test_orianna_identity_alignment.bats` could have been a tautology if it just asserted "the new script sets neutral identity, which we then assert is neutral." I checked by:

1. Cloning the PR branch to `/tmp/senna-pr57`
2. `git checkout 16b633e4 -- agents/orianna/memory/git-identity.sh` (restore the OLD persona-identity script)
3. Re-running the bats fixture with XFAIL=0
4. Result: test FAILED with "push-blocked" — the pre-push hook correctly rejected the persona-named author/committer

So the fixture really exercises Layer 3 against real persona identity. Confirms the failure mode is the one being protected against.

## Pattern: testing "this script changes git config" — pre-set with distinct placeholder

The fixture's `make_repo()` pre-configures the temp repo with `Duongntd` identity *before* sourcing `git-identity.sh`. This is brittle: a no-op script would also pass. Cleaner pattern (used in `scripts/hooks/test-hooks.sh:280`):

```sh
git -C "$dir" -c user.email="before@example.com" -c user.name="Before" \
  commit --allow-empty -q -m "init"
```

Then assert the post-source identity is the expected new value, distinct from "Before". This proves the script *acts*, not just *doesn't break a pre-set value*. Flagged as nit, not a blocker.

## Audit-signal scope shrinks (intentional but worth noting)

After this PR, `git log --author=Orianna` returns zero hits (Orianna's promotion commits author as Duongntd). The audit query becomes `git log --grep='Promoted-By: Orianna'`. No production gate parses `Promoted-By:` as authorization — the v2 commit-phase gate scripts (`test-orianna-gate-v2.sh`, `commit-msg-plan-promote-guard.sh`) are archived under `_archive/`, never wired. Plan authorization is enforced by `pretooluse-plan-lifecycle-guard.sh` at the Agent-tool dispatch level. So the trailer is metadata-only; trade is acceptable.

## Stale test assertions left after persona → neutral flip

After this PR lands, `scripts/hooks/test-hooks.sh:287-292` will FAIL:
```
=== agents/orianna/memory/git-identity.sh smoke ===
  FAIL: git-identity.sh — got email='103487096+Duongntd@users.noreply.github.com' name='Duongntd'
```
This is stale persona-era assertion. Not CI-blocking (test-hooks.sh is dev-invoked). Other stale persona refs:
- `scripts/orianna-bypass-audit.sh:54` (auto-detected from git-identity.sh, so adapts)
- `scripts/tests/test-orianna-bypass-audit.sh:35-119` (hardcoded persona for fixture setup)
- `scripts/hooks/test-orianna-gate-{v2,inv4-inv5}.sh` (test the v2 archived gate, not the live one)

Flagged as follow-up. Lucian's plan-lifecycle review may want to fold these into a cleanup commit.

## No-AI-attribution surface check

The PR adds prose containing the literal token `Orianna` to agent-def files. `commit-msg-no-ai-coauthor.sh` body-marker pattern is `(claude|anthropic|sonnet|opus|haiku|AI-generated)` — `Orianna` not in list. All four commits carry `Human-Verified: yes` trailer as the documented Rule-21 escape hatch. CI's `pr-no-ai-attribution` green.

## Reviewer-auth flow

Used `scripts/reviewer-auth.sh --lane senna gh pr review 57 --approve --body-file /tmp/senna-pr57-review.md`. Preflight `--lane senna gh api user --jq .login` returned `strawberry-reviewers-2` (correct).

## Cross-link

- Plan: `plans/approved/personal/2026-04-25-orianna-identity-protocol-alignment.md`
- Companion architecture: `architecture/git-identity-enforcement.md` §Orianna carve-out
- Layer 3 hook: `scripts/hooks/pre-push-resolved-identity.sh`
- Originating PR for Layer 2/3 enforcement: PR #56
