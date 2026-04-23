---
status: implemented
concern: personal
owner: karma
created: 2026-04-22
complexity: quick
tests_required: true
architecture_impact: none
tags: [governance, claude-md, pr-rules, rule-18]
related:
  - plans/pre-orianna/proposed/2026-04-17-branch-protection-enforcement.md
---

# Amend Rule 18 — allow agent self-merge when non-author review gate holds

## Context

Rule 18 in the repo-root `CLAUDE.md` currently prohibits an agent from merging any PR it authored, on top of the independent prohibitions on `--admin` bypass and red required checks. That belt-and-suspenders clause was written before the dedicated reviewer identities existed. Since then the system has built `strawberry-reviewers` (Senna lane) and `strawberry-reviewers-2` (Lucian lane) as distinct GitHub accounts expressly so agent-authored PRs can pick up a non-author approving review. Today's PRs #18 through #23 all cleared that structural gate but still required Duong to hit the merge button, creating friction that was never design-intended.

The safety invariant Rule 18 protects is **no self-approval loop** — a single identity must not be able to both author and rubber-stamp the merge. Gate (b) "one approving review from an account other than the PR author" already enforces that invariant because GitHub refuses same-identity approvals and the reviewer lanes are structurally separate accounts. The additional "must NOT merge a PR they authored" clause adds no new safety over (b); it only forbids the agent from clicking the merge button after (b) is already satisfied.

Amendment: delete the author-is-not-merger clause from Rule 18 and its downstream restatements. Keep every other prohibition: no `--admin`, no branch-protection bypass, no merging with a red required check, no merging without a non-author approval. Update consistent restatements in `architecture/pr-rules.md`, `architecture/git-workflow.md`, `architecture/testing.md`, `agents/memory/agent-network.md`, and the agent definition files that echo the old phrasing. No hook changes required — the scripts/hooks directory <!-- orianna: ok -- dir-path-token not a file ref --> contains no hook that encodes the author-is-not-merger rule (verified via grep); enforcement was purely social/documentary.

## Tasks

- T1 — kind: docs; estimate_minutes: 10; files: `CLAUDE.md`. Replace Rule 18 body. New wording enumerates the three gates (green required checks; one approving review from an account other than the PR author; no `--admin` or branch-protection bypass) and drops the "must NOT merge a PR they authored" clause. Keep the parenthetical pointer to `plans/pre-orianna/proposed/2026-04-17-branch-protection-enforcement.md §3` for break-glass rationale. DoD: rule renders the three-gate form; git diff touches only the Rule 18 block; `bash scripts/hooks/pre-commit-zz-plan-structure.sh` clean on the plan file; commit message `chore: amend rule 18 to permit self-merge when non-author review gate holds`.

- T2 — kind: docs; estimate_minutes: 8; files: `architecture/pr-rules.md`, `architecture/git-workflow.md`, `architecture/testing.md`, `agents/memory/agent-network.md`. <!-- orianna: ok -- prospective-line-refs-in-prose --> Sweep the four restatements. In pr-rules.md line 39, rewrite the trailing sentence to "Agents must not --admin-merge and must not merge a red PR — see CLAUDE.md rule 18." In git-workflow.md, retitle the "No self-merge / no --admin bypass" subsection to "No --admin bypass" and rewrite its body accordingly; also revise lines 152 and 154 so the "structurally satisfies Rule 18" prose reads as "satisfies Rule 18 gate (b)". In testing.md line 131 the wording already names only the non-author-reviewer rule and needs no change beyond a verify-read. In agent-network.md line 190, rewrite to the three-gate form matching the new Rule 18. DoD: `grep -n "merge a PR they authored"` returns zero hits; all four files still render coherently; no broken cross-references.

- T3 — kind: docs; estimate_minutes: 6; files: `.claude/agents/jayce.md`, `.claude/agents/viktor.md`, `.claude/agents/lucian.md`, `.claude/agents/senna.md`, `.claude/agents/talon.md`, `.claude/agents/_shared/quick-executor.md`, `.claude/agents/_shared/builder.md`. <!-- orianna: ok -- existing-agent-def-files --> Sweep the seven agent definitions that echo Rule 18. For executor/builder files (jayce.md, viktor.md, _shared/builder.md), replace the bullet "Never merge your own PR (Rule 18)" with "Never --admin-merge, never merge a red PR, always require a non-author approval before merge (Rule 18)". For reviewer files (lucian.md, senna.md), replace "Respect Rule 18: never approve-and-merge your own reviews" with "Respect Rule 18: never approve-and-merge from the same identity that authored the PR." For talon.md and quick-executor.md, the existing wording is already compatible and needs no change beyond a verify-read. DoD: `grep -rn "Never merge your own PR"` returns zero hits.

- T4 — kind: test; estimate_minutes: 10; files: `scripts/hooks/tests/test-rule-18-amendment.sh` (new). <!-- orianna: ok -- new-test-file-prospective --> Author a shell script that sanity-greps the amendment actually landed and encodes the safety invariants as xfail-style assertions. Assertions: (1) `CLAUDE.md` Rule 18 still contains the literal strings "gh pr merge --admin" and "branch-protection bypass"; (2) `CLAUDE.md` Rule 18 no longer contains the literal string "merge a PR they authored"; (3) `CLAUDE.md` Rule 18 contains a clause requiring "an approving review from an account other than the PR author" (or canonical equivalent phrase); (4) no file under architecture/ or agents/memory/ contains the phrase "must NOT merge a PR they authored"; (5) grep returns zero matches for "merge a PR they authored" across .claude/agents/ CLAUDE.md architecture/. Each assertion prints PASS or FAIL and the script exits non-zero on any FAIL. Do NOT wire into test-hooks.sh yet — run on demand. DoD: script is executable; fresh run on the amended tree exits 0; running the same script against HEAD~1 exits non-zero on at least assertions (2), (4), and (5).

- T5 — kind: docs; estimate_minutes: 4; files: `plans/pre-orianna/proposed/2026-04-17-branch-protection-enforcement.md`. Add a short §9 "Rule 18 amendment 2026-04-22" note recording that the author-is-not-merger clause was dropped, that gates (a) and (c) and the non-author-review requirement remain, and that no branch-protection-record change is needed (GitHub's author-cannot-approve-own-PR enforcement already covers gate (b)). DoD: the linked §3 content is unchanged; the new §9 reads as a strict pointer to the amendment, not a rewrite of §3; pre-orianna plan file retains its legacy frontmatter (no Orianna gate upgrade).

## Test plan

Invariants the new test-rule-18-amendment.sh <!-- orianna: ok -- new-test-file-prospective --> protects:

- (i) The prohibitions Rule 18 MUST keep — `--admin` and branch-protection bypass — remain literally present in the amended Rule 18. Any future edit that silently deletes them trips the script.
- (ii) The dropped clause "merge a PR they authored" does not creep back into Rule 18 or any downstream restatement. Prevents inadvertent re-introduction during a future mass-edit.
- (iii) The non-author-reviewer requirement is still the load-bearing safety gate in Rule 18 prose. If a future edit drops the non-author phrasing, the amendment's safety justification evaporates and the script catches it.

Sample xfail demonstration (the script itself, when run before the T1+T2 edits land, MUST exit non-zero) — this is the xfail-before-implementation commit required by Rule 12. Commit order on the branch: (1) add the test script with the assertions, confirm it fails against current `main` snapshot of Rule 18; (2) apply T1+T2+T3+T5 edits; (3) re-run the script, confirm it passes; (4) open PR.

Non-goals: the test script does NOT assert anything about GitHub branch-protection records, reviewer-lane PATs, or hook installation state. It is a pure-text sanity check on the amendment landing correctly.

## Decision

Drop the author-is-not-merger clause from Rule 18. Keep the `--admin`, branch-protection-bypass, and red-required-check prohibitions. The non-author-approval gate (b) is the load-bearing safety invariant and is structurally enforced by GitHub's author-cannot-approve-own-PR rule plus the separate `strawberry-reviewers` / `strawberry-reviewers-2` identities. No hook changes, no branch-protection-record changes required.

## Architecture impact

No architecture files modified by this plan. Rule 18 wording updated in CLAUDE.md and downstream docs (architecture/git-workflow.md, architecture/pr-rules.md, agents/memory/agent-network.md, agent definitions). No new architecture/ files created.

## Test results

- PR #24 merged at b9e3113: https://github.com/harukainguyen1411/strawberry-agents/pull/24
- All required checks green at merge.

## References

- `CLAUDE.md` Rule 18 (current wording)
- `architecture/git-workflow.md` §"Branch Protection — Required Checks and Review Enforcement"
- `architecture/pr-rules.md` §"Account Roles for PRs"
- `plans/pre-orianna/proposed/2026-04-17-branch-protection-enforcement.md` §3 (admin enforcement rationale)
