# PR #24 — Rule 18 self-merge amendment review

**Date:** 2026-04-22
**Verdict:** CHANGES_REQUESTED
**Branch:** feat/rule-18-self-merge-amendment

## What I caught

1. **Sweep miss — `architecture/cross-repo-workflow.md:25`.** Live architecture
   doc still said *"Agents must never merge their own PRs (CLAUDE.md rule 18)"*,
   directly contradicting the amendment. The sanity-grep test didn't catch it
   because Assertion 5 only greps for the exact phrase `merge a PR they authored`
   and missed the paraphrase `merge their own PRs`. I flagged both the doc line
   AND recommended broadening the test grep — fix the class of bug, not just
   the instance.

2. **Rule 18 wording ambiguity — "once (b) is satisfied".** Naming only gate (b)
   invites future readers to assume (a) and (c) are relaxed for self-merge.
   Governance rule ambiguity = security bug. Recommended "once (a), (b), and (c)
   are satisfied".

3. **Gate (c) tautology.** *"no `--admin` or branch-protection bypass"* duplicates
   the rule's opening clause. Maintenance smell — future editor may delete one
   and leave a gap.

## Method that paid off

- Ran xfail test against BOTH pre-amendment main AND PR branch to verify the
  "exits 1 before, 0 after" claim. Plan said assertions 2/4/5 should fail
  against main — actual run confirmed exactly that. Honest xfail discipline.
- Did a broader `grep -E "merge (a PR|your own|own PR|their own)"` sweep across
  `architecture/` on the PR branch, not just the scopes the PR's own test grepped.
  That's what surfaced the `cross-repo-workflow.md` miss.

## Lesson

When reviewing governance-text changes, don't trust the PR's own sanity-grep test
as the coverage oracle. Run the broader pattern sweep yourself. Sanity-grep tests
codify what the author THOUGHT to look for; review surfaces what they missed.

## Wording-as-security-bug pattern

For governance rules that relax a restriction, always check:
- Does the new wording explicitly re-affirm the UNRELAXED gates alongside the relaxation?
- Are there tautological clauses that look load-bearing but aren't?
- Is any downstream restatement still consistent?

A rule that says "you may X once Y" reads to a future agent as "Y is the ONLY
precondition". Restrict by enumerating all preconditions, not just the changed one.
