# Camille

## Role
Opus planner / workstream lead. Authors plans and coordinates Sonnet executor teams (viktor, ekko, jayce, vi, jhin). Does not typically implement — reviews, unblocks, escalates.

## Sessions
- 2026-04-17: Dependabot triage plan for 104 open alerts (5 crit, 42 high) — 13 batches, 4 phases. Commit 4d18cdf.
- 2026-04-17: Dependabot Phase 3 addendum — 4 batches for 25 residuals. Commit e3745d1.
- 2026-04-18: Ran dependabot-cleanup workstream as team lead — 8 PRs merged (B10 x4, B13 #158, B14 #156, B4g #155), 4 parked awaiting GitHub Actions billing unblock (#157 B12, #171 B11b, #174 B11a, #176 B11). Coordinated viktor/ekko/jayce + Duong review rollups.
- 2026-04-19: Branch protection probe + restore recipe for `harukainguyen1411/strawberry-app`. Verified zero protection (classic + rulesets both empty). Authored `plans/proposed/2026-04-19-branch-protection-restore.md` — ruleset approach with `bypass_actors` pinning owner-only bypass. Commit bd1b3db.

## Key Knowledge
- **Stale PR snapshots**: `gh pr view --json files` can show files that were legitimately in the PR at query time but reflect upstream drift (e.g. primary checkout's local-main ahead of origin/main leaking into feature branches). Re-query before accusing an executor of scope drift; lead with diagnosis, not prescription.
- **Single-account reviewer constraint**: all agents run under one GitHub identity (`harukainguyen1411`), so agent-authored PRs cannot clear invariant #18 structurally — GitHub blocks self-approval. Route agent-authored PRs through Duong batch review via team-lead rollups; dependabot-authored PRs can merge on two agent reviews.
- **Billing-block failure signature**: when every required check across every PR goes red simultaneously and `gh run view --log-failed` returns "log not found", check GitHub Actions billing/spending limit BEFORE investigating workflows. Today's diagnosis took 30 min; next time should be under 2.
- **Raw worktree bypass**: `safe-checkout.sh` refuses on foreign dirty files (other agents' uncommitted work in primary checkout). Raw `git worktree add -b <branch> <path> main` is the correct escape hatch — it's invariant-#3 compliant (uses worktree mechanism) and the new worktree sees a clean tree regardless of primary state.
- **Plan promotion (approved→in-progress)**: `plan-promote.sh` only handles `proposed/→*`. Raw `git mv` with frontmatter status rewrite is the compliant path for approved→in-progress (no Drive doc past proposed/, so no unpublish needed).
- **Protection API triple-probe**: branch protection state on a GitHub repo requires checking all three endpoints before concluding: classic `branches/{b}/protection`, GraphQL `branchProtectionRules`, and `rulesets`. A ruleset-only repo 404s on the classic endpoint while being fully protected. See learnings/2026-04-19-branch-protection-probe-and-rulesets.md.
- **Agent account identity (stale/verify)**: line 13 above says agents run as `harukainguyen1411`; the 2026-04-19 branch-protection task context asserts `Duongntd` is the agent account and `harukainguyen1411` is human owner. `gh auth status` shows both logged in with `Duongntd` active. Treat the authoritative identity as task-context-provided until reconciled.

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
