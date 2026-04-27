---
title: Align Orianna's git-identity protocol with three-layer enforcement
slug: orianna-identity-protocol-alignment
date: 2026-04-25
concern: personal
status: approved
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
---

## Problem

On 2026-04-25, Orianna ran a `proposed → approved` promotion following her standard protocol — sourced `agents/orianna/memory/git-identity.sh` (which sets `user.name=Orianna`, `user.email=orianna@strawberry.local`), committed with a `Promoted-By: Orianna` trailer at SHA `dffda377`, and tried to push. Layer 2 (pre-commit) honored the `STRAWBERRY_AGENT=orianna` carve-out and let the commit through, but Layer 3 (pre-push) **rejected** the push: `pre-push-resolved-identity.sh` has no Orianna carve-out by design (see `architecture/agent-network-v1/git-identity.md` §Layer 3 and §Orianna carve-out — "no carve-out. Orianna pushes neutral identity at push time"). Orianna recovered by amending the commit to neutral `Duongntd` identity, preserving the trailer in the body. Reactive amend-shuffling on every promotion is fragile; the protocol must produce a clean push on first try.

## Architecture decision

Orianna's persona signal lives **in the commit body as a `Promoted-By: Orianna` trailer**, not at the git author/committer level. The three-layer model already encodes this: Layer 2's carve-out exists only because Orianna *historically* committed under her persona identity, but Layer 3 deliberately omits the carve-out — the canonical resting state of an Orianna commit on the remote is `author=Duongntd, committer=Duongntd, body trailer=Promoted-By: Orianna`. The fix is to make Orianna's startup script produce that resting state directly, eliminating the amend round-trip. The Layer 2 carve-out is retained as belt-and-suspenders (harmless: a clean Duongntd commit short-circuits before the carve-out check matters), but Orianna's protocol no longer relies on it.

## Diff sketch

**`agents/orianna/memory/git-identity.sh`** — replace persona identity with neutral identity:

```sh
# OLD
git config user.email "orianna@strawberry.local"
git config user.name "Orianna"

# NEW
git config user.email "103487096+Duongntd@users.noreply.github.com"
git config user.name "Duongntd"
printf '[orianna] git identity set: neutral Duongntd (persona signal carried in Promoted-By trailer)\n' >&2
```

**`.claude/agents/orianna.md`** — update the Identity section to state neutral-at-git-level + trailer-as-signal, and tighten step 5 of "On APPROVE" to call out the trailer as the sole audit signal (commit body, not author/committer headers). No change to the existing `Promoted-By: Orianna` trailer requirement; that trailer is already the contract.

## Tasks

- **T1. xfail regression test** — kind: test. estimate_minutes: 25. files: `tests/hooks/test_orianna_identity_alignment.bats` (new). <!-- orianna: ok -- prospective path, created by this plan --> detail: bats fixture that initializes a temp repo with both pre-commit-resolved-identity.sh and pre-push-resolved-identity.sh installed, sources the *current* `agents/orianna/memory/git-identity.sh`, simulates a plan-promotion commit (with `Promoted-By: Orianna` trailer) under `STRAWBERRY_AGENT=orianna`, and runs `git push` against a local bare remote. Assert: commit succeeds AND push succeeds in a single pass with no `git commit --amend` between them. Mark xfail until T2 lands; reference plan slug in test header per Rule 12. DoD: test committed, fails red against current script, references this plan path.

- **T2. Update identity script** — kind: code. estimate_minutes: 10. files: `agents/orianna/memory/git-identity.sh`. detail: apply the diff above. Keep the script idempotent and POSIX-portable (Rule 10). Update the header comment to reference this plan and explain that persona signal lives in the commit trailer. DoD: T1 flips green; xfail marker removed in same commit.

- **T3. Update Orianna protocol doc** — kind: docs. estimate_minutes: 10. files: `.claude/agents/orianna.md`. detail: rewrite the "Identity" section to state neutral-Duongntd at git level; add one sentence to the "On APPROVE" step 5 noting the `Promoted-By: Orianna` trailer is the audit signal of record. Leave the `bash agents/orianna/memory/git-identity.sh` invocation line untouched (script content changes, call site does not). DoD: section reads cleanly; no contradictions with `architecture/agent-network-v1/git-identity.md`.

- **T4. Architecture doc cross-reference** — kind: docs. estimate_minutes: 5. files: `architecture/agent-network-v1/git-identity.md`. detail: under §Orianna carve-out, append a note: "Layer 2 carve-out is retained as defense-in-depth but Orianna's startup script now sets neutral identity directly; the carve-out is no longer load-bearing." DoD: note added; reference to this plan included.

## Test plan

Invariants protected:

1. **Single-pass clean promotion** — Orianna can commit-then-push a plan promotion without any amend, rebase, or identity reshuffle. Covered by T1.
2. **Trailer audit signal preserved** — every Orianna-promoted commit on the remote still carries `Promoted-By: Orianna` in the body. T1 asserts the trailer survives the push.
3. **Layer 3 unchanged** — `pre-push-resolved-identity.sh` is not touched by this plan. T1 reuses the live hook to prove Orianna's path is clean against the unmodified backstop.

Per Rule 12: T1 lands as a separate xfail commit before T2's implementation commit on the same branch.

## Open questions — RESOLVED 2026-04-25

1. Should Layer 2's `STRAWBERRY_AGENT=orianna` carve-out be removed entirely once T2 ships, or kept as defense-in-depth? (Plan currently keeps it; could be follow-up cleanup after one week of bake.)

> **Duong: keep as defense-in-depth.** Cheap; catches future drift if anyone reintroduces persona-identity at git level. No follow-up cleanup ticket needed.

2. Are there any historical Orianna-authored commits (persona identity at git level) on remote branches that need a retroactive sweep, or does the existing `architecture/agent-network-v1/git-identity.md` §"Out of scope: retroactive sweep" deferral cover this?

> **Duong: accept historical noise.** No `git filter-branch` sweep — rewriting shared history is risky and the audit trail (Promoted-By trailer) survives in body regardless. Existing "out of scope: retroactive sweep" deferral covers it.

3. The retrospection-dashboard cornerstone plan's canonical-v1-lock will gate edits to `.claude/_script-only-agents/` and hook scripts — does it also gate `.claude/agents/orianna.md` and `agents/orianna/memory/git-identity.sh`? If yes, T2/T3 must land before lock activation.

> **Duong: yes — must land pre-lock.** Per dashboard plan §Q6 the canonical-v1 manifest covers all `.claude/agents/*.md` SHAs (so `orianna.md` is locked) and the persona's behavior-defining script `agents/orianna/memory/git-identity.sh` is explicitly added to the lock manifest at lock-tag time. Promote and execute this plan before Phase 2 of the retrospection-dashboard ships, since Phase 2 ship triggers the lock.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Owner is Karma, all three open questions resolved inline by Duong on 2026-04-25, and tasks T1–T4 are concrete with explicit DoD. Test discipline honored: T1 lands an xfail bats test referencing this plan before T2's implementation commit, satisfying Rule 12. The fix scope is minimal — one script body change, two doc updates — and aligns the Orianna protocol with the canonical resting state already documented in `architecture/agent-network-v1/git-identity.md` (neutral git identity + `Promoted-By: Orianna` trailer as audit signal). Time-sensitive: must execute before retrospection-dashboard Phase 2 ship triggers canonical-v1 lock.
