# Last Session — 2026-04-08 (Mac evening, Direct mode, S28, post-restart)

**Mode:** Direct mode all the way. Restarted into a fresh Evelynn around 7:46 PM on Mac, worked until ~10:15 PM. First real Mac-side `/end-session` skill test.

## Critical for next session — read first

1. **Every agent's `model:` frontmatter takes effect THIS session** — you're fresh, definitions loaded cleanly at startup. Katarina spawns as Sonnet by default. Verify by watching the Max plan dashboard's Sonnet-only bar move above 0% after the first Sonnet spawn.
2. **Protocol migration paused at Commits 8 and 10** — plan lives at `plans/in-progress/2026-04-09-protocol-migration-detailed.md`. Duong gave three "yes" decisions ("1 sure, 2 now, 3 now"): (1) Commit 8 merge direction is port-then-delete (port missing sections from `GIT_WORKFLOW.md` into `architecture/git-workflow.md`, then `git rm` the root file); (2) push commits 6/7/9 — already done; (3) approve mcp-restructure phase-1 now to unblock Commit 10.
3. **Phase-1-detailed plan needs promotion** — `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` is verbally approved, run `scripts/plan-promote.sh` on it before spawning anyone to execute it.
4. **Shen and Fiora profiles are NOT wired** — seven aspirational specialists total (Ornn, Fiora, Reksai, Neeko, Zoe, Caitlyn, Shen) with no `.claude/agents/<name>.md`. Duong's rule: wire them, don't fake with general-purpose. Author Shen + Fiora profiles tonight BEFORE spawning them for Commit 8 and phase-1 execution. The other five can be folded into a dedicated wiring plan.
5. **Sister research agent plan — codename Bee** — `plans/proposed/2026-04-09-sister-research-agent-karma.md` (filename still says karma, content is Bee throughout). 9 open questions; the biggest is whether Claude Max subscription ToS allows automated cloud-backend use. Personal product for Duong's sister. Vietnamese .docx research companion. Every one of Syndra/Swain/Bard flagged the ToS question independently — don't move on infrastructure until it's answered.

## What shipped this session (slice 3 of 2026-04-08)

- **Sister research agent rough plan (Bee)** committed `dfcfe19` + revised `ac921d2`. Karma → Bee rename, NextAuth Google → shared password, cost concerns absorbed, playbook reference folded in. 4 inline `// ` directives from Duong applied by a general-purpose subagent that ran on Opus (should have been Poppy or Sonnet — flagged).
- **First real agent-team session** using `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Three teammates (Pyke, Swain, Bard), three tasks with dependency chain. Delivered: protocol-leftover audit (`assessments/2026-04-08-protocol-leftover-audit.md`, 625f789), operating-protocol-v2 (2cbc80e → 5bd1ea3 → 6c6e27e through revisions), protocol-migration-detailed 10-commit plan (a078979 → 06a9b5b → 9a33a80 → 7f64f52).
- **Rule 15 landed** — every `.claude/agents/<name>.md` must declare `model:`. CLAUDE.md updated. 7 existing definitions got frontmatter (opus/sonnet/haiku per tier). Commit `eb6c0a9`.
- **Katarina migration execution** — promoted plan to approved (`0e6eba1`) → in-progress (`96ddb72`) → executed Commits 1, 3, 4, 5, 6, 7, 9. Commit 2 was no-op (Zilean already absent). Stopped at 8 (merge-direction blocker) and 10 (phase-1 dependency).
- **clean-jsonl.py platform resolver fix** — detailed plan (`0b22cd3`), Katarina executed with explicit `model: "sonnet"` override, commit `0a0a52d`, plan to implemented. Unblocked this very `/end-session` close. First Sonnet spawn of the session (all earlier Katarina runs were Opus because of the cached-definition bug).
- **Five new feedback memories** — model-explicit (tightened for session-startup caching), evelynn-primary-tools (teams/subagents/Yuumi, not legacy MCP), subagents-background (always run_in_background), no-git-while-subagent-running (shared tree hazard), no-general-purpose-fallback (wire or use wired, never pretend).

## Open threads (priority order)

1. **Wire Shen and Fiora profiles** — blocker for the migration finish.
2. **Promote phase-1-detailed to approved/** — needed before Commit 10 can run.
3. **Execute migration Commit 8** — Shen (once wired) with a port-then-delete mini-spec.
4. **Execute phase-1-detailed end-to-end** — Fiora (once wired). 16 steps. Her own drift sweep is embedded.
5. **Execute migration Commit 10** — Katarina. Unblocked after phase-1 lands.
6. **Final migration promotion** — Katarina moves the migration plan to implemented/ after Commit 10.
7. **CLAUDE.md line 28 stale `agents/roster.md` reference** — tiny follow-up, `agents/roster.md` was deleted by migration Commit 7 but line 28 still points at it.
8. **Plan Step 4 defect in `2026-04-09-clean-jsonl-platform-resolver.md`** — the Windows-simulation smoke test can't run on Mac pathlib. Post-mortem cleanup, not urgent.
9. **Wiring debt plan** — propose a dedicated plan to author Ornn, Reksai, Neeko, Zoe, Caitlyn profiles alongside Shen + Fiora.
10. **Sister-agent plan 9 open questions** — especially Max ToS for automated backend use (blocking), quota contention with autonomous pipeline, and whether the sister wants a character-forward Bee or a flat tool.
11. **Max plan quota** — this session ran at ~52% of current-session quota pre-restart. All Opus burn. Next session should show Sonnet usage >0% as soon as any Sonnet subagent runs.

## Lessons saved (cross-reference for memory hygiene)

- `feedback_agent_model_explicit.md` (tightened — now covers session-startup caching + first-failure case)
- `feedback_evelynn_primary_tools.md`
- `feedback_subagents_background.md`
- `feedback_no_git_while_subagent_running.md`
- `feedback_no_general_purpose_fallback.md` (tightened — now covers general-purpose model override + first-failure case)

## Ended cleanly

First successful Mac-side `/end-session evelynn` invocation after the cleaner fix. Working tree empty going in. Single session-close commit + push at the end.
