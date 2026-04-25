# PR #65 — architecture-consolidation Wave 2 — code-quality + structural review

## Verdict
REQUEST CHANGES — two critical broken cross-refs (C1 in `infrastructure.md`, C2 in `communication.md`) plus one important Rule-14 conflation in the §Q6 Lock-Bypass contract that, left as-is, could enable bypass abuse by misleading readers about enforcement.

## Top findings (severity-ordered)

**Critical**
- C1: `infrastructure.md` references three archive files that don't exist anywhere (`archive/2026-04-25-discord-relay.md`, `-telegram-relay.md`, `-mcp-servers.md`). Verified via `git ls-tree origin/architecture-consolidation-wave-2 -r --name-only architecture/archive/`. The doc claims `mcp-servers.md` "was archived on 2026-04-25" — false at merge time.
- C2: `communication.md` line 53 points to `plans/in-progress/personal/2026-04-25-coordinator-decision-feedback-plan.md`. Real path: `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md` — different stage, date, and filename.

**Important**
- I1: Lock-Bypass contract conflates Rule 14 (pre-commit unit-test hook) with `--no-verify` ban for canonical-v1 paths. No hook today inspects canonical-v1 paths; the framing makes readers think Rule 14 enforcement covers Lock-Bypass when it doesn't. Suggested: replace with honest "enforced by reviewer attention until `commit-msg-canonical-v1-lock` hook ships" language.
- I2: `architecture/canonical-v1.md` doesn't exist yet — measurement-week trigger file is dangling. Contract is dormant; doc should say so explicitly.
- I3: Lock-Bypass `reason` field has no minimum bar — `Lock-Bypass: needed` would syntactically pass. Recommended: require plan path / rule number / break-glass timestamp citation.
- I4: `agents/<coordinator>/audit/` directory doesn't exist — first bypass would have to create it. Worth a `.gitkeep` precursor or a one-line note.

**Minor**
- M1: PR body overstates pr-rules.md rule coverage (claims 14+19; file correctly omits both since they don't fire at PR stage).
- M2: typo "referenceble" → "referenceable" in communication.md.
- M3: `scripts/deploy/rollback.sh` referenced but doesn't exist (also wrong in CLAUDE.md Rule 17 — out of PR scope to fix there).
- M4: Lissandra context drift between agents.md and pr-rules.md; clarify "memory consolidator (replaces former PR-reviewer role)".
- M5: git-workflow.md missing worktree cleanup section (`git worktree remove`).
- M6: git-workflow.md missing edge case warning about `--worktree`-scoped `core.hooksPath` breaking hook inheritance.

## Process notes (for future Senna sessions)

1. **PR-file checkout for review without HEAD-switch**: `git checkout origin/<branch> -- <paths>` restores files into working tree without touching HEAD. Cleanup with `git checkout HEAD -- <committed-paths> && rm <new-files>`. Doesn't violate Rule 3 because HEAD doesn't move.
2. **Cross-ref verification pattern**: when reviewing canonical/architecture docs, run `find` and `ls` on every file path mentioned in the rewritten content. The W2 PR had two broken refs that pure prose-reading wouldn't catch — only ground-truth checks against the filesystem and `git ls-tree` against the branch surfaced them.
3. **Lock-Bypass contracts are advisory until enforced**: when reviewing a "MUST" contract that has no hook/CI backing, flag the enforcement gap explicitly. Conflating an advisory contract with an enforced rule (like I1's Rule-14 framing here) is the exact pattern that enables bypass abuse — the reader sees "treated as Rule 14 violations" and assumes tooling catches it.
4. **PR-body claims should be checked against file content**: PR body said pr-rules.md consolidates Rules 5/12/13/14/15/16/17/18/19/21. File covers 5/11/12/13/15/16/17/18/21. The mismatch was intentional (Rule 14 / 19 don't fire at PR stage) but the PR body wasn't updated. Worth flagging as M-tier.

## Auth used
`scripts/reviewer-auth.sh --lane senna gh pr review 65 --request-changes ...` — confirmed `strawberry-reviewers-2` identity, posted as CHANGES_REQUESTED at 2026-04-25T15:01:06Z (review ID PRR_kwDOSGFeXc745Rft). Lucian had already posted CHANGES_REQUESTED 5 minutes earlier on different (plan-fidelity) findings — both blocking; no overlap, complementary lanes worked as designed.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/65#pullrequestreview-... (id 745Rft)
