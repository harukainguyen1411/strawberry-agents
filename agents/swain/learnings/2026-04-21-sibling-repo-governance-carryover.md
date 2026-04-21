# Sibling-repo governance carryover

When an ADR proposes a new sibling repo (rather than adding under `apps/` in an existing one), the rollout plan must explicitly carry over three things or the repo will silently drift from house rules:

1. **Pre-commit hooks** — copy via `install-hooks.sh` from the parent repo, first task in phase 1. Not optional. The new repo will not inherit them automatically.
2. **Commit-prefix convention** — state which conventional-commit prefixes apply and how they scope. A new repo with no `apps/**` still needs `chore:` / `feat:` scoping decided at plan time, not at first commit.
3. **Playwright / CI gate applicability** — CLAUDE.md's universal invariants reference "PR to main" without naming a repo. Every new repo creates an ambiguity: does rule X apply here? Flag it as an explicit OQ in the plan, don't let the ambiguity land silently.

Skipping any of these means the first PR in the new repo discovers the gap, which is exactly the "stale enforcement claim" class of drift I flagged on 2026-04-19 — now inverted: the rule text implies universal coverage, but the enforcement artifact (hooks, CI workflows) lives in one repo and must be mirrored.

Corollary: ADRs that spawn a new repo should include a `Governance carry-over` subsection in the rollout section — not bury it inside a task bullet.
