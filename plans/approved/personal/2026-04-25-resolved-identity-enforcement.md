---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [git-identity, hooks, security, defense-in-depth, pivot]
related:
  - scripts/hooks/pretooluse-subagent-identity.sh
  - scripts/install-hooks.sh
  - scripts/hooks/commit-msg-no-ai-coauthor.sh
  - scripts/hooks/agent-identity-default.sh
  - architecture/plan-lifecycle.md
references:
  - PR #45 review by Lucian (NEW-BP-4 through NEW-BP-12 reproducers): https://github.com/harukainguyen1411/strawberry-agents/pull/45
---

# Resolved-identity enforcement (post-PR-#45 pivot)

## 1. Context

PR #45 introduced `scripts/hooks/pretooluse-subagent-identity.sh` — a PreToolUse Bash hook that scans shell command source for persona-name patterns adjacent to `git commit`. Senna approved on a first pass. Lucian's follow-up review found nine NEW bypasses (NEW-BP-4 through NEW-BP-12: line-continuations, backticks, `$(...)` command substitution, `eval`, `sh -c`, `bash -c`, `git commit-tree`, `$V`-style indirection). All nine were reproduced live producing `Viktor <viktor@strawberry.local>` author commits while the hook returned exit 0.

Lucian's diagnosis is structural, not regex-tuning: PreToolUse is pre-execve. It sees shell **source**, never the resolved values shell expansion will produce. Every regex tightening opens another indirection door. Unbounded.

Pivot (Option A from Lucian's review, chosen by Duong): move the primary gate to a **`pre-commit` hook** that reads `git var GIT_AUTHOR_IDENT` and `GIT_COMMITTER_IDENT` — by then shell expansion is finished and git has resolved the final identity strings. A single regex against the resolved string catches every indirection variant. Add a **`pre-push` hook** doing `git cat-file commit <sha>` on each pushed commit to close the `git commit-tree` path (which skips `pre-commit`). Keep PR #45's PreToolUse scanner as **defense-in-depth** — it still catches the easy cases and shortens the feedback loop.

## 2. Decision

- **Primary gate**: client-side `pre-commit` hook reading resolved `GIT_AUTHOR_IDENT` / `GIT_COMMITTER_IDENT` via `git var`.
- **Backstop**: client-side `pre-push` hook walking pushed shas with `git cat-file commit`. (Server-side `pre-receive` deferred — same logic, separate plan if/when needed.)
- **Defense-in-depth**: PR #45's PreToolUse scanner stays in place; documented as advisory layer.
- **Allowlist**: neutral identity `Duongntd <103487096+Duongntd@users.noreply.github.com>`. Orianna carve-out preserved via existing identity-resolution path (frontmatter `agent_type` → `CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT`); `pre-commit` honors `STRAWBERRY_AGENT=orianna` for her cosmetic-approval commits. Pre-push has no Orianna carve-out (she pushes neutral identity).
- **Regex**: persona-name set (Viktor, Lucian, Senna, Aphelios, Xayah, Caitlyn, Akali, Karma, Talon, Azir, Swain, Kayn, Lux, Sona, Evelynn, Orianna — full roster from `agents/memory/agent-network.md`) plus catch-all `@strawberry.local` email domain. Match either author OR committer header.

### 2.1 PR-#45 handling — recommendation: **CLOSE #45, open NEW PR**

Reasoning: PR #45's PreToolUse scanner is fundamentally insufficient as a primary gate (Lucian's NEW-BP-* set proves the regex arms race is unwinnable). Landing #45 first means shipping a known-broken gate with a "stronger fix coming" promise — tempts callers to rely on it, muddies the audit story, and produces a noisy revert/refactor commit when the new hooks land. A clean replacement PR is honest about the pivot.

The PreToolUse scanner itself is preserved verbatim — it gets carried into the new PR (or rebased onto main from #45's branch) as advisory defense-in-depth, with documentation marking it as non-primary. Nothing of #45's code is wasted; only the framing changes.

Action: T9 closes #45 with a comment linking the new PR and explaining the layering.

## 3. Tasks

- [ ] **T1 — kind: test, estimate_minutes: 35.** Files: `tests/hooks/test_pre_commit_resolved_identity.sh` (new) <!-- orianna: ok --> ; `tests/hooks/test_pre_push_resolved_identity.sh` (new). <!-- orianna: ok --> Detail: adapt Lucian's NEW-BP-4 through NEW-BP-12 reproducers from the PR #45 comment into nine xfail cases per hook (eighteen total). Each case sets up a temp git repo, configures a persona-named author/committer via the bypass technique under test (line-continuation, backtick, `$(...)`, `eval`, `sh -c`, `bash -c`, `git commit-tree`, `$V` indirection, plus a baseline plain-author case as control), then invokes the not-yet-existent hook script and asserts non-zero exit + persona-name in stderr. Mark each test xfail referencing this plan. Commit before T2. DoD: tests run, all xfail, committed in a single commit tagged `chore: xfail tests for resolved-identity enforcement (T1)`.

- [ ] **T2 — kind: code, estimate_minutes: 30.** Files: `scripts/hooks/pre-commit-resolved-identity.sh` (new). <!-- orianna: ok --> Detail: bash script reading `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`. Apply persona-name regex (full roster, word-boundary, case-insensitive) and `@strawberry.local` email regex against both. On match: print fail-loud diagnostic naming the violating header + resolved value, exit 1. Honor `STRAWBERRY_AGENT=orianna` env to skip (Orianna carve-out). Allowlist exact match `Duongntd <103487096+Duongntd@users.noreply.github.com>`. POSIX-portable per Rule 10. DoD: T1's pre-commit cases flip from xfail to pass; xfail markers removed in same commit.

- [ ] **T3 — kind: code, estimate_minutes: 30.** Files: `scripts/hooks/pre-push-resolved-identity.sh` (new). <!-- orianna: ok --> Detail: bash script reading stdin lines `<local-ref> <local-sha> <remote-ref> <remote-sha>` per git pre-push protocol. For each new commit (`git rev-list <remote-sha>..<local-sha>` when remote-sha non-zero, else `git rev-list <local-sha> --not --remotes`), run `git cat-file commit <sha>` and grep author/committer headers against the same regex set as T2. On match: print fail-loud diagnostic with sha + offending header, exit 1. Same allowlist; NO Orianna carve-out (she pushes neutral). POSIX-portable. DoD: T1's pre-push cases flip from xfail to pass; xfail markers removed in same commit.

- [ ] **T4 — kind: code, estimate_minutes: 15.** Files: `scripts/install-hooks.sh`. Detail: extend the installer to symlink/install `pre-commit-resolved-identity.sh` into the `pre-commit` chain and `pre-push-resolved-identity.sh` into `pre-push`. Mirror existing chain pattern (look at how `pre-commit-secrets-guard.sh` and `pre-push-tdd.sh` are wired). DoD: fresh `bash scripts/install-hooks.sh` in a clean clone installs both new hooks; idempotent on re-run.

- [ ] **T5 — kind: code, estimate_minutes: 10.** Files: `scripts/hooks/pretooluse-subagent-identity.sh` (carry-over from PR #45). Detail: add a header comment explicitly marking this hook as **defense-in-depth, advisory-only** with a pointer to `pre-commit-resolved-identity.sh` as the primary gate. Reference NEW-BP-4..12 to explain why it cannot be the primary gate. No behavior change. DoD: comment block present; no test assertions touch this file.

- [ ] **T6 — kind: docs, estimate_minutes: 15.** Files: `architecture/git-identity-enforcement.md` (new). <!-- orianna: ok --> Detail: short architecture note documenting the three-layer model (PreToolUse advisory → pre-commit primary → pre-push backstop), the regex set, the allowlist, the Orianna carve-out scope (pre-commit only), and the rationale anchored in Lucian's PR #45 NEW-BP-* findings. Link back to this plan. DoD: file committed; CLAUDE.md universal-invariants list (Rule list in repo root) NOT modified by this plan — that lift happens only after the new hooks bake for one week.

- [ ] **T7 — kind: test, estimate_minutes: 10.** Files: `tests/hooks/test_pre_commit_resolved_identity.sh`, `tests/hooks/test_pre_push_resolved_identity.sh`. Detail: add two POSITIVE tests per hook — (a) neutral `Duongntd` identity passes both, (b) `STRAWBERRY_AGENT=orianna` with persona-named author passes pre-commit but FAILS pre-push (carve-out boundary). DoD: tests pass against T2/T3 implementations.

- [ ] **T8 — kind: code, estimate_minutes: 10.** Files: `scripts/install-hooks.sh`. Detail: append a smoke test stanza at the end of the installer that runs the four test files (`tests/hooks/test_pre_commit_resolved_identity.sh`, `tests/hooks/test_pre_push_resolved_identity.sh`, plus the existing `test_commit_msg_no_ai_coauthor.sh` already wired). Surface failures fail-loud. DoD: `bash scripts/install-hooks.sh` runs the suite; output greps `OK` for each.

- [ ] **T9 — kind: ops, estimate_minutes: 10.** Files: none (GitHub action). Detail: after the new PR merges, close PR #45 with a comment: "Superseded by #<NEW>. Lucian's NEW-BP-4..12 review showed the PreToolUse scanner cannot serve as a primary gate (regex arms race vs shell indirection). The scanner survives in the new PR as advisory defense-in-depth; the primary gate is now the resolved-identity `pre-commit` + `pre-push` hooks per `architecture/git-identity-enforcement.md`." DoD: PR #45 closed with comment; new PR linked.

## 4. Test plan

Tests live in `tests/hooks/` and run from `scripts/install-hooks.sh` smoke stanza plus pre-existing CI test discovery.

Invariants the tests protect:

1. **No persona-name author/committer commits land locally** — pre-commit blocks every NEW-BP-4..12 indirection variant after resolution. This is the primary invariant; if it regresses, the entire pivot has failed.
2. **`git commit-tree` cannot smuggle persona identity onto a remote** — pre-push catches sha-level violations by reading the actual commit object headers, bypassing whatever commit-creation path was used.
3. **Neutral `Duongntd` identity passes** — false-positive regression guard.
4. **Orianna carve-out is scoped to pre-commit only** — she may sign at commit time; she may not push persona-named commits. Boundary test enforces this.
5. **Idempotent installer** — re-running `install-hooks.sh` does not duplicate hook entries or break the chain.

Per Rule 12, T1 commits the xfail suite first. T2 and T3 each flip their respective subsets to passing in the same commit that adds the implementation. T7 adds the positive/boundary cases after the gate is green.

## 5. Out of scope

- Server-side `pre-receive` hook (GitHub-side). Deferred — client-side pre-push is sufficient for Strawberry's threat model (single-developer + agent fleet, all pushes from machines we control). Revisit if a multi-machine or untrusted-runner scenario emerges.
- Retroactive sweep of historical commits with persona authors. Separate ops task.
- Updating CLAUDE.md universal-invariants (Rule list) to reference the new hooks as the authoritative gate. Wait one week post-merge; promote to invariant only after the hooks bake without false positives.

## 6. References

- Lucian PR #45 review (NEW-BP-4..12 reproducers): https://github.com/harukainguyen1411/strawberry-agents/pull/45
- Existing PreToolUse scanner: `scripts/hooks/pretooluse-subagent-identity.sh` (PR #45 branch)
- Identity-default helper: `scripts/hooks/agent-identity-default.sh`
- Hook installer: `scripts/install-hooks.sh`
- Plan lifecycle: `architecture/plan-lifecycle.md`

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan is concrete and well-owned (karma), with nine tasks each carrying file paths, estimates, and DoDs. Rule 12 is honored: T1 commits eighteen xfail reproducers (Lucian's NEW-BP-4..12 across both hooks) before T2/T3 flip them green. The three-layer model (PreToolUse advisory, pre-commit primary via `git var GIT_AUTHOR_IDENT`, pre-push backstop via `git cat-file commit`) is structurally motivated — each layer closes a specific bypass class, not speculative generality. Allowlist, Orianna carve-out scope (pre-commit only), and PR-#45 closure path are all explicit. Out-of-scope deferrals (server-side pre-receive, CLAUDE.md invariant lift) are appropriately bounded.
