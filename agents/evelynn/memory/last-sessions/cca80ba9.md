# Last Session — 2026-04-18 (S47, Mac, direct mode)

Big migration session. Duong initiated public-repo split + agent-infra split + token-budget rebalance.

## Shipped

1. **Agent roster rebalanced** for Opus budget: Azir/Kayn/Caitlyn xhigh→high; Aphelios/Neeko high→medium; Skarner haiku→sonnet (Haiku retiring); Swain revived as the sole xhigh all-rounder (do not invoke unless Duong asks). Name fields capitalized across agent defs. `agents-table.md` created at repo root.
2. **Public-repo migration executed through Phase 5 + A1.**
   - `harukainguyen1411/strawberry-app` created (public), 1-commit orphan main, 5-context branch protection, 8 labels, 16 secrets pasted, smoke PR #18 merged, 10/11 workflows green (the 1 red is a pre-existing Preview workflow bug with no-dist guard — deferred).
   - 17 files parametrized via env vars / template expressions / positional args. New `scripts/hooks/check-no-hardcoded-slugs.sh` + `lint-slugs.yml` CI job.
   - **strawberry-agents Phase A1 done:** history preserved via filter-repo --invert-paths, 914 commits, gitleaks clean-enough for private repo. Filtered tree at `/tmp/strawberry-agents-migration` ready for A2+.
   - `Duongntd/strawberry` docs updated (CLAUDE.md two-repo section, architecture/*.md, new `architecture/cross-repo-workflow.md`).
3. **Account roles inverted in memory:** `harukainguyen1411` = human/owner/reviewer with bypass; `Duongntd` = agent account / collaborator / no bypass / canonical pusher. Commit `80cd16f`. Note: fine-grained PATs don't work across user accounts as collaborator — classic PAT with `repo` + `workflow` scope is the only viable path for Duongntd to push to harukainguyen1411/strawberry-app. `AGENT_GITHUB_TOKEN` reminted from Duongntd, old harukainguyen1411 token revoked.
4. **Tag `migration-base-2026-04-18` = `af2edbc0`** on Duongntd/strawberry — shared base SHA for both migrations.
5. **Guard 4 allowlist extended** to `agents/*/memory/`, `agents/*/journal/`, `agents/*/learnings/`, `agents/*/transcripts/`, `plans/*`, `architecture/*`.
6. **Retro fact-check by Yuumi** caught the Firebase GitHub App bug mid-migration. Established: any plan referencing an external integration must include grep-style evidence. Planned as post-migration work: new Sonnet agent **Orianna** = fact-checker + quarterly memory auditor; mandatory gate in `plan-promote.sh`.

## Scope changes decided mid-session

- `bee-worker` moves to strawberry-app (public), overrode Azir's default
- Formal TDD skipped for migration ops → Caitlyn's 57-gate checklist + Aphelios's +33 AG gates = 90 combined gates
- Agent pattern for future: **sequential spawns** not TeamCreate for phase-gated work (cheaper on cache)
- Discord relay secrets skipped (relay not deployed anywhere currently; workflows exit 0 when vars unset)

## Open — pick up next session

1. **Phase 4 — replay PRs #152 + #161** into strawberry-app (Duong said "replay both"). Fresh Ekko spawn.
2. **A2** — rewrite slug refs in strawberry-agents filtered tree (Viktor). Note the 17-file set from strawberry-app P2 doesn't directly apply — A2 scope is mostly plan-file URLs + memory SHA refs.
3. **A3** — push strawberry-agents to new remote, set secrets, apply minimal branch protection per D9 (no force-push, no delete, zero review required).
4. **A4** — local working-tree swap. Duong's laptop switches from `~/Documents/Personal/strawberry` to `~/Documents/Personal/strawberry-agents` as canonical agent-infra checkout. Coordination-heavy — needs Duong in loop.
5. **A5** — memory footer injection ("pre-2026-04-19 SHAs resolve against Duongntd/strawberry archive") + pinned README on Duongntd/strawberry archive.
6. **A7** — orphan-path sentinel check: every file in Duongntd/strawberry at base SHA must be in exactly one of strawberry-app OR strawberry-agents OR retired-allowlist.
7. **A6** — 90-day archive trigger at 2026-07-18. Far future, set a reminder.
8. **Orianna ADR + grep-style rule + memory audit role** — post-migration plan. Azir writes.
9. **Post-migration backlog**: fix Preview workflow no-dist guard, deploy discord-relay properly (likely Cloud Run), rotate Telegram bot token + Cloud Run demo token in transcript `2026-04-17-e0b93856.md`.

## Key realizations

- Opus 4.7 has flat $5/$25 per MTok (no tier split — I was confusing it with Sonnet 4.5's 1M tier). On Max x20 subscription, usage scales with context size because conversation history gets resent every turn. `/clear` is the single biggest lever for quota.
- Prompt cache 5-min TTL is sliding window (resets on hit), not absolute lifetime. 1h extended cache not available in Claude Code CLI.
- **Plans must ground integration claims empirically.** Azir wrote "install Firebase GitHub App" without checking that all four deploy workflows actually use `FIREBASE_SERVICE_ACCOUNT` key auth. Cost ~15 min of Duong hunting for a Console option that didn't exist. Same pattern for stale Hetzner refs in architecture/*.md (discord-relay was moved to GCE).
- **Collaborator model on personal GitHub accounts does not support fine-grained PATs.** Must use classic PATs with `repo` + `workflow` scope. GitHub org-ownership would unlock fine-grained, but not worth the restructure.

## Blockers for next session

None hard-blocking — Phase 4 + A2-A7 can start immediately with background spawns. A3 will need Duong in-loop for:
- New PAT for strawberry-agents (likely classic `repo` scope, maybe narrower since it's private)
- Setting secrets in strawberry-agents (probably just `AGE_KEY` + `AGENT_GITHUB_TOKEN` — private repo has no deploy workflows per D7)
