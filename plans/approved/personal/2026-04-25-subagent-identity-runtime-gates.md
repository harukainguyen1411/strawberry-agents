---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
supersedes: plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md
tags: [identity, subagent, git-author, pre-commit, pre-push, defense-in-depth, gate-bypass-learning]
related:
  - plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md
  - plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md
  - agents/senna/learnings/2026-04-24-pr45-subagent-git-identity-universal-request-changes.md
  - agents/senna/learnings/2026-04-24-pr45-round2-two-new-bypasses.md
  - agents/senna/learnings/2026-04-24-pr45-round3-three-new-bypasses.md
  - agents/senna/learnings/2026-04-24-pr45-round4-shlex-class-of-bug-incomplete.md
  - scripts/hooks/pretooluse-work-scope-identity.sh
  - scripts/hooks/pre-commit-reviewer-anonymity.sh
  - scripts/hooks/_lib_reviewer_anonymity.sh
---

# Subagent git identity — runtime gates (pre-commit + pre-push primary, PreToolUse defense-in-depth)

## 1. Context

This plan supersedes `plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md`, whose architecture (PreToolUse string-scanning of `git commit` invocations) was proven structurally incomplete across four review rounds on PR #45 (`talon/subagent-git-identity-as-duong`). Senna's round-4 finding is the load-bearing one: bash expansion semantics (backticks, `$(...)`, `eval`, `sh -c "..."`, `bash -c "..."`, line-continuation, variable references, `commit-tree` plumbing) resolve at exec time, not at tokenization time. PreToolUse only sees pre-expansion source text. No tightening of the regex, shlex tokenizer, or token allowlist closes the gap — the runtime sees something different from what the hook scanned. <!-- orianna: ok -->

The fix is to move the primary gate to a layer that sees the **post-expansion** identity. Two layers do: (a) `pre-commit` reading `git var GIT_AUTHOR_IDENT`, which git has fully resolved by combining env vars, `-c` overrides, `--author`, worktree config, and global config; and (b) `pre-push` running `git cat-file commit <sha>` over each pushed commit's `author` line, which closes the `commit-tree` plumbing escape (commits crafted via `git commit-tree` skip `pre-commit` entirely but cannot skip `pre-push`). PreToolUse remains as a tripwire — it catches the obvious shapes early and emits a friendly block — but it is no longer the invariant guarantor. <!-- orianna: ok -->

This plan also captures the gate-chain learning: the original design shipped through Karma planning, Talon implementation, Senna review × 4. The system worked as intended — Senna's lane caught a structural defect the planner missed, and four rounds of review escalated from canonical-shape bypasses (BP-1/2/3) to quoted-form bypasses (NEW-BP-1/2/3) to a class-of-bug architectural finding (NEW-BP-4 through NEW-BP-12). The cost of those four rounds is the price of having a real review gate. Treating the cost as evidence the gate works — not as evidence the gate is too slow — is the lesson to encode.

## 2. Decision

**Architecture.** Three layers, ordered by authority:

1. **Primary — `pre-commit` hook reads `git var GIT_AUTHOR_IDENT`.** The hook fails the commit if the resolved author matches a persona denylist (`*@strawberry.local`, persona-name tokens like `Viktor`, `Jayce`, `Aphelios`, etc.) OR fails an allowlist of acceptable identities (`*@users.noreply.github.com` + Orianna's carve-out `orianna@strawberry.local` when `CLAUDE_AGENT_NAME=Orianna`). `git var GIT_AUTHOR_IDENT` is the resolved identity post env/`-c`/`--author`/config — there is no expansion-evasion at this layer. Closes NEW-BP-1 through NEW-BP-9 and NEW-BP-11/12.

2. **Primary — `pre-push` hook walks pushed commits via `git rev-list <range>` + `git cat-file commit <sha>` and scans each `author` line.** Same denylist + allowlist as `pre-commit`. Closes NEW-BP-10 (`git commit-tree` plumbing skips `pre-commit` but the resulting commit still surfaces in `git push` and is scanned).

3. **Defense-in-depth — `PreToolUse` keeps the existing rewrite-worktree-config behavior** for `git commit` Bash dispatches. It catches the canonical leak shape early with a friendly message before the user even hits commit-time, but it is explicitly documented as a tripwire, not an invariant gate. Bypass found at this layer is a UX issue, not an invariant violation, as long as `pre-commit` + `pre-push` hold.

**Migration on PR #45.** Recommend **close PR #45 and open a fresh PR from a new branch**. Rationale: (a) the four review rounds on `talon/subagent-git-identity-as-duong` produced a regex-then-shlex tokenizer that is now dead-code in the new architecture; preserving its commits adds review noise without value. (b) The new architecture touches different files (`pre-commit-*`, `pre-push-*`) primarily, with only a small reduction-of-scope change to the existing PreToolUse hook — keeping the old branch's PreToolUse rewrites would force reviewers to mentally diff "what's primary now" vs "what's tripwire". (c) Senna's four review threads on PR #45 are valuable archeology but they are review noise on the new approach. A clean PR with a clean review surface costs ~10 minutes of branch setup and saves hours of reviewer time. Close PR #45 with a comment linking to this plan and the new PR; do not delete the branch (keep it as the artifact of the architectural-incompleteness lesson). <!-- orianna: ok -->

**What survives from PR #45.**
- The env-merge precedence fix in `scripts/hooks/agent-identity-default.sh` (`{**existing_env, **neutral_env}`) — verified solid by Senna round 1, keep.
- The Orianna carve-out resolution (`CLAUDE_AGENT_NAME` / `STRAWBERRY_AGENT` / `subagent_type` chain) — keep, lift into the new pre-commit hook's exemption logic.
- The xfail-first commit discipline (`502180f2` xfail before `6dad4f45` impl) — pattern survives; new branch follows the same Rule 12 sequencing.

**What is discarded from PR #45.**
- The shlex tokenizer in `pretooluse-subagent-identity.sh` (the round-4 attempt at primary enforcement). The PreToolUse hook reverts to its original lightweight rewrite-worktree-config posture, explicitly marked as tripwire.
- The denylist regex in PreToolUse (no longer load-bearing; the same denylist lives in the pre-commit hook where it has full visibility).
- The 38-test suite under PR #45's `tests/test-identity-leak-fix.sh` — replaced by a new test suite anchored on `git var GIT_AUTHOR_IDENT` and `git cat-file commit` invariants, not on regex coverage of attack shapes.

**Why quick lane.** One domain (identity-hook chain), no schema, no new external integration, ≤ 4 tasks, ≤ 90 AI-min. The escalation criterion ("escalate if you want more than 3 paragraphs of context") was tested against this brief — the context fits, with the structural finding load-bearing rather than complex.

## 3. Non-goals

- No history rewrite on the dirty `missmp/company-os` commits (d7241b0e, 9c9b0f2e, f83d4b5e). Forward-only stance from the prior plan stands.
- No change to Orianna's plan-promotion identity (`orianna@strawberry.local` remains; carve-out replicated in the new layer).
- No removal of `scripts/hooks/pretooluse-work-scope-identity.sh` — it is reduced in scope, not deleted, so its tripwire UX value is preserved.
- No new external CI workflow. `pre-commit` and `pre-push` hooks run locally; CI's existing `pre-push`-equivalent gate (the secret-scanning + commit-prefix workflow) gains an author-line check inline.
- No coverage of human-typed commits authored as Duong (already correct identity); the gate is a no-op for them.

## 4. Tasks

### T1. Xfail: pre-commit must reject persona-resolved author identity

- kind: test
- estimate_minutes: 20
- files: `scripts/hooks/tests/test-precommit-author-identity.sh` (new). <!-- orianna: ok -->
- detail: Shell test that (a) creates a temp git repo, (b) configures `user.email=viktor@strawberry.local` locally, (c) stages a trivial change, (d) attempts `git commit` and asserts the commit is rejected with a clear message naming the persona-leak invariant. Second case: `GIT_AUTHOR_EMAIL=jayce@strawberry.local git commit` — must also reject (this is the case PreToolUse-shlex could not catch). Third case: `git -c user.email=viktor@strawberry.local commit` — must reject. Fourth case: `eval "GIT_AUTHOR_NAME=Viktor git commit"` — must reject (the round-4 NEW-BP-7 case; pre-commit sees the resolved identity regardless of how it got there). Fifth case: Orianna exemption — when `CLAUDE_AGENT_NAME=Orianna` is set, allow `orianna@strawberry.local`. Sixth case: clean Duong identity passes. Commit BEFORE T2 per Rule 12. Must xfail on current main (no such hook exists yet — `pre-commit-reviewer-anonymity.sh` is gated on `[:/]missmp/` per Senna round-2 finding).
- DoD: test file exists, executable, xfails against current main; reference this plan in the commit body.

### T2. Implement pre-commit author-identity gate

- kind: script
- estimate_minutes: 35
- files: `scripts/hooks/pre-commit-author-identity.sh` (new), `scripts/hooks/_lib_reviewer_anonymity.sh` (extend with shared denylist/allowlist if not already factored), `scripts/install-hooks.sh` (wire), `.claude/settings.json` (no change — pre-commit hooks are git-native, not Claude-tool hooks). <!-- orianna: ok -->
- detail: New POSIX bash hook that calls `git var GIT_AUTHOR_IDENT`, parses `Name <email> timestamp tz`, and checks the email + name against (a) denylist: `*@strawberry.local` and persona-name token list (Viktor, Jayce, Aphelios, Xayah, Caitlyn, Kayn, Talon, Karma, Senna, Lucian, Sona, Evelynn, Akali, Orianna, Swain, Azir — sourced from `agents/memory/agent-network.md` if available, else hardcoded with a TODO to migrate); (b) allowlist: `*@users.noreply.github.com` + Orianna carve-out (when `CLAUDE_AGENT_NAME=Orianna` OR `STRAWBERRY_AGENT=Orianna` OR resolved `subagent_type=orianna`, allow `orianna@strawberry.local`). Drop the `[:/]missmp/` origin gate that exists on the current `pre-commit-reviewer-anonymity.sh` — universal coverage per the prior plan's intent. POSIX-portable bash per Rule 10. Wire into `scripts/install-hooks.sh` so the standard install picks it up. Document in the hook header that this is the **primary** invariant gate; PreToolUse is tripwire only.
- DoD: T1 flips green; `bash scripts/hooks/test-hooks.sh` regression passes; manual smoke shows the hook firing on a `viktor@strawberry.local` commit attempt.

### T3. Implement pre-push commit-tree-escape gate + reduce PreToolUse to tripwire

- kind: script
- estimate_minutes: 30
- files: `scripts/hooks/pre-push-author-identity.sh` (new), `scripts/hooks/pretooluse-work-scope-identity.sh` (revert/simplify), `scripts/install-hooks.sh` (wire), `scripts/hooks/tests/test-prepush-author-identity.sh` (new). <!-- orianna: ok -->
- detail: New POSIX bash pre-push hook reads stdin per git's pre-push protocol (`<local_ref> <local_sha> <remote_ref> <remote_sha>` per line), computes `git rev-list ${remote_sha}..${local_sha}` for each, runs `git cat-file commit <sha>` for each commit in the range, parses the `author ` line, and applies the same denylist/allowlist as T2 (factor the check into `_lib_reviewer_anonymity.sh`). Test: a commit crafted via `git commit-tree` with a persona-author tree object — pre-commit is bypassed, pre-push catches it. Simultaneously, **reduce** `pretooluse-work-scope-identity.sh`: keep its rewrite-worktree-config behavior for `git commit` invocations, but remove the shlex tokenizer / denylist-regex layer added in PR #45 (it was load-bearing before; it is tripwire now). Update the hook header to say "Tripwire only — primary invariant lives in `pre-commit-author-identity.sh` and `pre-push-author-identity.sh`."
- DoD: pre-push test passes (commit-tree escape blocks); PreToolUse hook diffstat shows reduction, not expansion; `bash scripts/hooks/test-hooks.sh` green; full hook chain test (PreToolUse → pre-commit → pre-push) on a sandbox repo demonstrates each layer firing on its appropriate input.

### T4. Document the runtime-gate architecture + record the gate-bypass learning

- kind: doc-edit
- estimate_minutes: 20
- files: `architecture/agent-network-v1/git-identity.md`, `agents/karma/learnings/2026-04-25-pretooluse-string-scan-class-of-bug.md` (new), `plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md` (annotate as superseded). <!-- orianna: ok -->
- detail: In `architecture/agent-network-v1/git-identity.md`, replace the previous-plan's "Git identity discipline" subsection (or add it if T4 of the prior plan never landed) with: "Identity invariants are enforced at runtime by `pre-commit-author-identity.sh` (reads `git var GIT_AUTHOR_IDENT` post-resolution) and `pre-push-author-identity.sh` (reads `git cat-file commit <sha>` to close the `commit-tree` escape). The PreToolUse hook is a tripwire UX layer — bypassing it is not an invariant violation as long as the runtime gates hold." Cite this plan and the four Senna review learnings. New Karma learning file captures the class-of-bug rule: "PreToolUse string-scanning cannot be the primary gate for any property that depends on bash runtime expansion — backticks, `$(...)`, `eval`, `sh -c`, `commit-tree` plumbing, line-continuation. Move the gate to the layer that sees the resolved value." Append a one-line "Superseded by `plans/approved/personal/2026-04-25-subagent-identity-runtime-gates.md`" annotation at the top of the prior plan's §1.
- DoD: architecture doc updated; new learning file exists with the class-of-bug rule; prior plan annotated; `git grep -n "PreToolUse.*primary.*identity"` returns zero hits in `architecture/`.

## 5. Test plan

Invariants protected:

1. **No commit lands with author `*@strawberry.local`** (except Orianna's plan-promotion commits within `strawberry-agents`) — protected by T2 (pre-commit) and T3 (pre-push). T1 cases 1-4 cover the four bypass classes from PR #45's review rounds (canonical, env-prefix, `-c` override, `eval`-wrapped).
2. **`commit-tree` plumbing escape is closed** — T3's pre-push test specifically targets NEW-BP-10.
3. **Orianna carve-out preserved** — T1 case 5 + T2 allowlist branch.
4. **PreToolUse remains a useful UX tripwire but bypassing it is not a security failure** — T3 explicitly reduces its role; documented in T4.

Test cases derived from the PR #45 review history (each is a regression test the new design must keep closed):

| Tag | Source | Case | Expected layer that catches |
|-----|--------|------|------------------------------|
| BP-1 | Senna round 2 | `git -c "user.email=viktor@..." commit` | pre-commit |
| BP-2 | Senna round 2 | `git commit --author "Viktor <...>"` | pre-commit |
| BP-3 | Senna round 2 | `GIT_AUTHOR_NAME=Viktor` (name-only) | pre-commit |
| NEW-BP-1 | Senna round 3 | `-c 'user.email=...;'` (metachar in quote) | pre-commit |
| NEW-BP-2 | Senna round 3 | `GIT_AUTHOR_NAME='Viktor Kesler'` | pre-commit |
| NEW-BP-3 | Senna round 3 | `GIT_AUTHOR_NAME='The Viktor'` (suffix) | pre-commit |
| NEW-BP-4 | Senna round 4 | `GIT_AUTHOR_NAME=Viktor \<newline>git commit` | pre-commit |
| NEW-BP-5 | Senna round 4 | `` GIT_AUTHOR_NAME=`echo Viktor` `` | pre-commit |
| NEW-BP-6 | Senna round 4 | `GIT_AUTHOR_NAME="$(printf Vik; printf tor)"` | pre-commit |
| NEW-BP-7 | Senna round 4 | `eval "GIT_AUTHOR_NAME=Viktor git commit"` | pre-commit |
| NEW-BP-8 | Senna round 4 | `V=Viktor; GIT_AUTHOR_NAME=$V git commit` | pre-commit |
| NEW-BP-9 | Senna round 4 | `GIT_AUTHOR_NAME=$(cat /file) git commit` | pre-commit |
| NEW-BP-10 | Senna round 4 | `git commit-tree` plumbing | pre-push |
| NEW-BP-11 | Senna round 4 | `sh -c "GIT_AUTHOR_NAME=Viktor git commit"` | pre-commit |
| NEW-BP-12 | Senna round 4 | `bash -c "..."` | pre-commit |

Every row in the table maps to an assertion in T1 or T3's test files. The unifying argument: pre-commit reads the resolved identity, so attack mechanics become irrelevant — only the resolved value matters, and that is what the gate scans.

Execution:
- `bash scripts/hooks/tests/test-precommit-author-identity.sh` — primary gate, all 12 BP cases plus Orianna exemption.
- `bash scripts/hooks/tests/test-prepush-author-identity.sh` — commit-tree escape coverage.
- `bash scripts/hooks/test-hooks.sh` — full hook suite regression.
- Manual smoke: in a personal-concern worktree, attempt each of the four representative shapes (canonical, env-prefix, `-c`, `eval`) and confirm pre-commit blocks each with a clear message.

## 6. References

- Superseded plan: `plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md`
- Senna PR #45 round 1: `agents/senna/learnings/2026-04-24-pr45-subagent-git-identity-universal-request-changes.md` (BP-1/2/3 canonical bypasses)
- Senna PR #45 round 2: `agents/senna/learnings/2026-04-24-pr45-round2-two-new-bypasses.md` (quoted-form bypasses)
- Senna PR #45 round 3: `agents/senna/learnings/2026-04-24-pr45-round3-three-new-bypasses.md` (NEW-BP-1/2/3, recommendation to pivot to shlex)
- Senna PR #45 round 4: `agents/senna/learnings/2026-04-24-pr45-shlex-class-of-bug-incomplete.md` (NEW-BP-4 through NEW-BP-12, Option A architectural recommendation — load-bearing for this plan)
- PR #45: https://github.com/harukainguyen1411/strawberry-agents/pull/45 (to be closed on promotion of this plan)
- Existing PreToolUse hook (to be reduced): `scripts/hooks/pretooluse-work-scope-identity.sh`
- Existing reviewer-anonymity helpers (to be extended): `scripts/hooks/_lib_reviewer_anonymity.sh`, `scripts/hooks/pre-commit-reviewer-anonymity.sh`
- Universal invariant 1 (commit identity): `CLAUDE.md` cross-system rules ("never include AI authoring references in commits")

## 7. Gate-bypass learning (process artifact)

This plan exists because the design that shipped through Karma → Talon → Senna on PR #45 had a structural defect. The defect was not caught at planning (Karma did not flag the runtime-vs-lex-time gap), was not caught at implementation (Talon faithfully implemented the spec across four rounds), and was caught at review by Senna over four rounds escalating from canonical-shape bypasses to a class-of-bug architectural finding.

The lesson is **not** "the planner should have seen this earlier." The lesson is "the gate chain caught a structural defect across four rounds, which is the system working as intended." Four rounds of Senna review took ~3 hours of reviewer time. The alternative — shipping a permeable identity gate to main — would have cost weeks of leak triage. The four-round cost is the price of having a real review gate; treating it as friction rather than as the gate doing its job would be the wrong response.

The artifact rule (recorded in `agents/karma/learnings/2026-04-25-pretooluse-string-scan-class-of-bug.md` per T4): for any invariant that depends on a value resolved by the bash runtime (commit author, env vars, file paths after expansion, anything touched by `eval`/`sh -c`/`commit-tree`), the primary gate must run at the layer that sees the resolved value, not at the layer that sees the source text. PreToolUse is for UX tripwires; runtime gates are for invariants.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan supersedes a prior approved plan whose architecture was proven structurally incomplete across four PR #45 review rounds. Owner (karma) is clear; tasks are concrete with files, estimates, and DoD; Rule 12 xfail-first sequencing is explicit (T1 before T2). Test plan maps every BP/NEW-BP regression case to the layer that catches it. Three-layer architecture (pre-commit primary, pre-push for commit-tree escape, PreToolUse tripwire) each carries a named invariant — not speculative defense-in-depth. Orianna carve-out preserved. No unresolved gating decisions.
