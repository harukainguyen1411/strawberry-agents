# Evelynn — Open Threads

Last updated: 2026-04-26 (Lissandra pre-compact consolidation, shard 48ac7433).

---

## PR #93 (T.P2.3 decision-rollup fidelity) — awaiting Senna r3

**Current status (2026-04-27 ~00:20):** Viktor r3 landed at `74ed130a` on `dashboard-T.P2.3`. All 3 B1 JSDoc-terminator sites in `tools/retro/ingest.mjs` (lines 11, 35, 173) fixed by replacing globs with prose form. Module-load sweep clean across all 8 mjs files. `regression-pr88-fixes.test.mjs` 10/10 green (C1/C2/I4/I5 all pass — none were pre-existing). R5/R6 describe blocks added (decision-ingest 16/16). Lucian r2 already APPROVED (review `4177157280`). Senna r2 caught the missed sites (review `4177163413`).
**Next:** Dispatch Senna r3 only (no Lucian re-review needed — r3 doesn't touch plan surface). On Senna APPROVE → merge PR #93. Then T.P2.5 + Phase 3 chain.
**Shard:** 48ac7433 (handoff continuation; Senna+Lucian r2 reviews + Viktor r3 fix landed post-shard)

---

## Dashboard Phase 1 — SHIPPED

**Current status (2026-04-25):** PR #59 MERGED at 13:34:52Z (`0ff7d031`). Four review cycles (Senna CHANGES_REQUESTED x2, Senna APPROVE, Lucian APPROVE). Today's stated sole mission accomplished.
**Next:** Phase 2 = canonical-v1 manifest + retro skill + prompt-quality v1.5. Gate: architecture-consolidation must complete first.
**Shard:** 2b638235

---

## Cornerstone Plan A (agent-feedback-system) — RESOLVED

**Current status (2026-04-26):** PR #63 MERGED 2026-04-25T16:04:48Z (APPROVED). RESOLVED.
**Next:** None.
**Shard:** f6b6dc2e

---

## Cornerstone Plan B (coordinator-decision-feedback) — MERGED

**Current status (2026-04-25):** PR #64 merged at `0ea2959f`. Senna round 2 APPROVE (`PRR_kwDOSGFeXc745hl-`, 16:13) + Lucian round 2 APPROVE. Branch delete blocked by worktree at `/private/tmp/strawberry-coordinator-decision-feedback` — left in place per protocol.
**Post-merge advisories S1-S4 (Senna, review `PRR_kwDOSGFeXc745hl-`) — follow up on T7 PR or separate quick-lane:**
- S1: stale xfail `T5-skill-stdin-pipe-documented` in `test-decision-capture-skill.sh:72` — remove or rewrite to assert `--file` documented.
- S2: `test-decision-capture-skill.sh` + `test-end-session-step-6c.sh` still in xfail mode (missed in `c664fef7` flip) — flip to assert mode.
- S3: bind-contract validators at `_lib_decision_capture.sh:122/156/184/205` fire unconditionally on `DECISION_RENAME_*` in prod — consider gating on `DECISION_TEST_MODE=1` to match accessor pattern.
- S4: `concurred:true + match:false` counts as match in `_lib_decision_capture.sh:811` — add one-line comment clarifying intent.
**Next:** Dispatch T7 (Lissandra parity) follow-up. Address S1-S4 in T7 PR or separate quick-lane.
**Shard:** f6b6dc2e

---

## Coordinator routing discipline — PR #57 and PR #58 shipped

**Current status (2026-04-25):** PR #57 merged (orianna-identity-protocol-alignment, tip `b1d85e15`). PR #58 merged (coordinator-routing-discipline) — cheat-sheet at `architecture/agent-network-v1/routing.md`, `_shared/coordinator-routing-check.md` include sourced by both coordinators, two structured lane/pair-set pauses. Three coordinator slips logged at `feedback/2026-04-25-coordinator-discipline-slips.md`. Slip 3 (compact-watch miss) NOT covered by PR #58 — candidate for canonical-v1 retro.
**Next:** Internalize routing check pause on every dispatch. Slip 3 fix deferred to canonical-v1 retro.
**Shard:** 56777883

---

## canonical-v1 lock-watch

**Current status (2026-04-25):** Lock activates at dashboard Phase 2 ship. All `.claude/agents/*.md` and hook edits must land pre-lock.
**Next:** Track any outstanding infra changes before Phase 2 ships.
**Shard:** 56777883

---

## PR #69 — RESOLVED

**Current status (2026-04-26):** MERGED via Duong admin commit. RESOLVED.
**Next:** None.
**Shard:** 15249699

---

## PR #73 — monitor-arming-gate-bugfixes — MOOT, closing

**Current status (2026-04-26):** The hook being fixed (`pretooluse-monitor-arming-gate.sh`) has been removed entirely (commit `cd20732b`). PR #73 is moot. Ekko #35 dispatched to close the PR.
**Next:** Verify Ekko closed PR #73. Verify `plans/approved/personal/2026-04-26-monitor-arming-gate-bugfixes.md` archived by Orianna via Ekko.
**Shard:** 15249699

---

## Statusline implementation route — undecided

**Current status (2026-04-26):** Lux research complete. Native path exists: `rate_limits.{five_hour,seven_day}.used_percentage` in Claude Code statusline stdin JSON on Pro/Max accounts. Spec at `assessments/research/2026-04-26-claude-usage-statusline.md`. Dispatch route not decided: (a) polling hook, (b) extend pre-compact-save skill, (c) standalone shell alias. Not addressed in this leg due to inbox-watcher incident consuming ~4h.
**Next:** Present a/b/c options to Duong and await pick. Then dispatch implementation.
**Shard:** 15249699

---

## Plan-lifecycle-guard merge-commit exemption — gap not yet filed

**Current status (2026-04-26):** Guard fires on merge commits containing plan-path tokens in commit message. Merge commits are structurally read-only re: plan dirs. No exemption logic exists. Discovered via PR #69 block.
**Next:** File Karma quick-lane plan when capacity allows.
**Shard:** 7d8667a0

---

## Inbox watcher PreToolUse hook — REMOVED

**Current status (2026-04-26):** Root cause identified: hook had no `matcher` field, firing on every tool call. Duong directive: remove all three hook entries. Removed in commit `cd20732b`. The inbox-watcher PreToolUse gate no longer exists. Monitor arming is now informational only (coordinator boot). Feedback filed at `feedback/2026-04-26-convenience-promoted-to-forcing-function.md` (problem-only, no proposed solution).
**Next:** None. RESOLVED.
**Shard:** 15249699

---

## Three plans pending Orianna archival (Ekko #35)

**Current status (2026-04-26):** Ekko #35 in flight. Tasks include Orianna x3 to archive: `plans/in-progress/personal/2026-04-24-strawberry-inbox-channel.md`, `plans/implemented/personal/2026-04-24-coordinator-boot-unification.md`, `plans/approved/personal/2026-04-26-monitor-arming-gate-bugfixes.md`. These plans implemented features that have now been removed.
**Next:** Verify Ekko completed the three archival promotions via `ls plans/archived/personal/` on resume.
**Shard:** 15249699

---

## Architecture-consolidation — Waves 3/4 remaining

**Current status (2026-04-26):** Wave 0 (PR #61 MERGED 2026-04-25T13:19:32Z), Wave 1 (PR #62 MERGED 2026-04-25T13:41:28Z), Wave 2 (PR #65 MERGED 2026-04-25T15:29:12Z) all confirmed merged. Lock-Bypass §Q6 contract folded into Wave 2. Wave 3 = whole-file archives. Wave 4 = cross-ref sweep (must address CLAUDE.md:11/118/133 stale paths flagged by Jayce in W1 PR body). All waves must complete before canonical-v1 lock activates (at Phase 2 dashboard ship).
**Next:** Dispatch Wave 3. Wave 4 follows. Canonical-v1 lock target: post-Phase-2-dashboard.
**Shard:** f6b6dc2e

---

## Swain synthesis 20-OQ decision — RESOLVED

**Current status (2026-04-26):** Duong skip-to-concurred all 20 OQs with recommended-`a` defaults on 2026-04-25 (confirmed in `plans/approved/personal/2026-04-25-unified-process-synthesis.md` §7.5). All 6 ADRs promoted. RESOLVED.
**Next:** None.
**Shard:** f6b6dc2e

---

## 6 ADRs in proposed — promoted; W0–W4 implementation pending

**Current status (2026-04-26):** All 6 ADRs now in `plans/approved/personal/` (plan-of-plans, parking-lot, frontend-uiux, assessments-folder-structure, structured-qa-pipeline, pr-reviewer-tooling, unified-process-synthesis). Duong skip-to-concurred all 20 Swain OQs with recommended-`a` defaults on 2026-04-25. W0–W4 wave-plan implementation is the next action.
**Next:** Dispatch W0–W4 implementation per wave plan in unified-process-synthesis §6.
**Shard:** f6b6dc2e

---

## PR #66 (parallel-slice doctrine) — RESOLVED

**Current status (2026-04-26):** PR #66 MERGED 2026-04-25T15:56:31Z. RESOLVED.
**Next:** None.
**Shard:** f6b6dc2e

---

## clean-jsonl --since-last-compact — SHIPPED

**Current status (2026-04-25):** PR #60 merged (`c1463b56`). `scripts/clean-jsonl.py` now supports `--since-last-compact`. Transcript-excerpt gap closed. Future Lissandra runs can produce compact-excerpt files.
**Next:** None. RESOLVED.
**Shard:** 2b638235

---

## Akali QA fix-stack — DEFERRED

**Current status (2026-04-26):** Duong dismissed as stale 2026-04-26. Plans in `plans/proposed/personal/` (akali-qa-discipline-hooks.md, qa-two-stage-architecture.md) remain unactioned.
**Next:** No action unless Duong reopens.
**Shard:** bc09be92

---

## Lux monitoring research — RESOLVED for v1

**Current status (2026-04-26):** Six OQs closed in retrospection-dashboard plan §7 ("RESOLVED 2026-04-25"). Langfuse rejected for v1. Dashboard authoring unblocked per artifact state. Thread closed.
**Next:** None. RESOLVED.
**Shard:** 71c24fd3

---

## Cornerstone plans — breakdowns done, impl gated on Duong decisions

**Current status (2026-04-25):** Both cornerstone plans broken down and test-planned this leg. Plan A (agent-feedback-system): 16 tasks, 11 test tasks, implementation gated on slicing decision. Plan B (coordinator-decision-feedback): 12 tasks, 11 tests, gated on Plan A in-progress. See dedicated threads above for per-plan status.
**Next:** Duong's slicing decision for Plan A unblocks Viktor. Plan B follows.
**Shard:** 56777883

---

## Coordinator deliberation primitive — SHIPPED

**Current status (2026-04-25):** PR #49 merged (`7cb7fb07`). `_shared/coordinator-intent-check.md` inlined into both `.claude/agents/evelynn.md` and `.claude/agents/sona.md`. Three sections: intent block, surgical-trap recognition, altitude classifier. Senna caught a critical wiring defect (build-time `<!-- include: -->` marker shipping as dead text); Talon revised with proper inline at `600876a0`. Deliberation primitive now lives at coordinator boot. Self-bound into working context for this session.
**Next:** Monitor in practice. Cross-concern port to Sona is complete (included in PR #49). No further action.
**Shard:** e7221955

---

## Anti-AI-attribution defense-in-depth — SHIPPED

**Current status (2026-04-25):** PR #53 merged (`a08daf10`). Three-layer hardening: (a) `_shared/no-ai-attribution.md` inlined into all 30 agent defs via `scripts/sync-shared-rules.sh`, (b) `scripts/hooks/commit-msg-no-ai-coauthor.sh` extended to universal `Co-Authored-By:` block, (c) `.github/workflows/pr-lint.yml` job `pr-no-ai-attribution` + `scripts/ci/pr-lint-no-ai-attribution.sh`. `Human-Verified: yes` trailer overrides all three. Senna found F1/F2 bypass gaps (variant spellings like `Sonnet4.6`, `(Sonnet)`, `[Opus]`); Talon revised. Cross-repo port to work concern is Sona's lane (FYI delivered via `/agent-ops send sona`).
**Next:** None for personal concern. Sona's lane: cross-repo port.
**Shard:** e7221955

---

## Orianna git-index race anomaly — open observation

**Current status (2026-04-25):** Observed twice this session: sibling sync commits absorb staged plan moves into their commit body (e.g. `3dc8bbd8` "chore: sync agent memory and learnings" absorbed Orianna's PR #45-pivot promotion). Plan ends up correctly on disk but audit trail is contaminated. No fix in flight.
**Next:** Surface to Duong or commission Azir for an ADR on commit-timing isolation between Orianna promotions and concurrent memory-sync commits.
**Shard:** e7221955

---

## Filing-question reflex learning — queue

**Current status (2026-04-25):** Failure pattern identified this session: asking *where* to put words (which file, which section) instead of *what* behavioral change would accomplish the goal. Captured in deliberation primitive but warrants a standalone learning entry.
**Next:** File `agents/evelynn/learnings/2026-04-25-filing-question-reflex.md`. Low priority — can fold into next session close.
**Shard:** e7221955

---

## Cross-agent learning drift sweep — RESOLVED

**Current status (2026-04-25):** ~30 untracked learnings from Lucian, Senna, Sona, Syndra sessions committed as `9bd022e5`. Gitignore hygiene added for `.no-precompact-save`, `scheduled_tasks.lock`, QA artifacts.
**Next:** None. RESOLVED.
**Shard:** bc09be92

---

## Queued backlog — Duong directive (finish in-flight first)

Per Duong via Sona FYI (inbox archive `20260424-0759-017564.md`): finish in-flight work before pulling fresh plan items. Route cross-concern system/pattern fixes to Evelynn. Commission Karma plans for these after Talon #59 lands.

1. ~~**Rule 19 guard hole.**~~ **RESOLVED** — PR #43 merged. Pre-commit hook variant now rejects protected-plan-dir paths in staged index unless committing identity is Orianna. Plan implemented at `e05b59be`. Karma #64 planned, Orianna #66 promoted, Talon #68 implemented, dual-APPROVE, merged.
2. ~~**Plan-checkbox-vs-git-history audit pattern.**~~ **RESOLVED** — Skarner found Sona already codified this in `agents/sona/learnings/2026-04-24-stale-plan-checkbox-state.md`. Personal adoption: same rule applies whenever I read open-threads.md checkbox state.
3. ~~**scripts/plan-promote.sh phantom reference cleanup.**~~ **RESOLVED** — Yuumi scrubbed 30 prescriptive references across 17 files (commits `467dc48b`, `465c5b9b`). Historical references in implemented/archived plans left intact.

All three backlog items resolved. Finish-in-flight directive fully executed.

---

## Reviewer-auth concern-split — RESOLVED

**Current status (2026-04-24):** PR #42 merged. Senna APPROVE (4 non-blocking nits), Lucian APPROVE (1 non-blocking pre-existing path typo). Plan promoted to implemented at `22ec765a` / `063b8901`.
**Next:** None. RESOLVED.
**Shards:** 8df9ce09, 3bc945c0

---

## MCP consolidation + Slack Node 25 fix — RESOLVED

**Current status (2026-04-25):** PR #44 merged (`80b78802`). Both plans promoted to `plans/implemented/personal/`. Yuumi amended in-flight to drop stale Firebase-rotted `evelynn` MCP. Ekko diagnosed slack-MCP reconnect fail post-merge: `node_modules/` absent in new location; hardened start.sh with auto-install (commit `f81aaf26`). T5 (`rm -rf strawberry/`) explicitly NOT executed — gated on Duong confirmation. Strawberry archive repo still contains apps/, deploy/, agents/ — not minimal MCP host.
**Next:** Surface T5 deletion decision to Duong post-stability-window.
**Shard:** c1463e58

---

## PR #56 — resolved-identity-enforcement — RESOLVED

**Current status (2026-04-26):** PR #56 MERGED 2026-04-25T08:21:31Z (APPROVED). RESOLVED.
**Next:** None.
**Shard:** bc09be92

---

## Rule 19 guard-hole — RESOLVED

**Current status (2026-04-24):** PR #43 merged. Pre-commit hook now rejects staged protected-plan-dir paths unless committing identity is Orianna. Karma #64 planned, Orianna #66 promoted (`62a9b3f6`), Talon #68 implemented, Senna+Lucian dual-APPROVE, merged. Plan implemented at `e05b59be`.
**Next:** None. RESOLVED.
**Note:** AST scanner false-positive on plan-path substrings in `gh pr review --body` arg — workaround is `--body-file`. Follow-up pass needed; queue Karma when capacity allows.
**Shard:** 3bc945c0

---

## Cross-concern FYI pattern — codified

**Current status (2026-04-24):** Mandatory unprompted coordinator-to-coordinator FYI pattern now codified in agents/memory/agent-network.md (commit 5f894715). Both coordinators required to send FYIs for cross-concern events (shared agents, shared scripts, universal invariant amendments). Triggered by Duong's direct praise of Sona's Akali-breach FYI. Learning filed: `agents/evelynn/learnings/2026-04-24-sona-unprompted-cross-concern-fyi.md`. Two reciprocal FYIs already sent to Sona this session.
**Next:** None — rule is live. Practice on every qualifying event.
**Shard:** 8df9ce09

---

## Rule 12 drift — pre-push-tdd.sh shell-test gap

**Current status (2026-04-24):** Lucian flagged non-blocking on PR #41: T1+T3 (xfail + impl) landed in the same commit due to pre-push-tdd.sh not gating shell-only tests. Systemic gap — shell tests are not covered by the TDD gate. Not blocking current work.
**Next:** Commission a follow-up plan (Karma quick-lane) to close the gap when capacity allows. Not urgent.
**Shard:** 8df9ce09

---

## Identity-leak fix — RESOLVED

**Current status (2026-04-24):** PR #35 MERGED — dual approval (Lucian + Senna, round 2 after REQUEST CHANGES), merge commit `90c830012d`. Covers: xfail-first TDD, regex bypass fix for `git -c` / `git -C`, denylist single-source-of-truth (I2), fail-closed hardening (I1). Talon's impl landed cleanly.
**Shards:** 4f8b78fd, bd9bb7cc.
**Next:** None for the fix itself. Residual: personal-scope subagent identity mis-attribution (separate thread below).

---

## Universal worktree isolation — SHIPPED

**Current status (2026-04-24):** PR #37 merged (opt-in → opt-out flip; ADR promoted to implemented at 760f3ac6 + 3be20a2d). PR #38 merged — subagent-merge-back.sh polish (4 Senna findings). All new subagent dispatches auto-isolate; call scripts/subagent-merge-back.sh for every subagent returning a branch. Individual Kayn opt-in question is moot — universal default covers it.
**Next:** Monitor behavior; verify Sona inbox-monitor asymmetry root cause is closed by PR #39.
**Shards:** 4f8b78fd, bd9bb7cc, 683a3ab7

---

## Sona inbox monitor asymmetric — root cause identified, fix pending

**Current status (2026-04-24):** Root cause confirmed: `scripts/hooks/inbox-watch-bootstrap.sh` reads `.agent` field from project-root `.claude/settings.json`, hardcoded to `'Evelynn'`. Sona sessions don't export `STRAWBERRY_AGENT` at launch, so watcher always spawns as Evelynn. Monitor works Sona→Evelynn; silent Evelynn→Sona.
**Fix options:** (a) Add `STRAWBERRY_AGENT=Sona` export to Sona's coordinator launch alias, or (b) runtime-agent-context resolution in the bootstrap script.
**Next:** Implement fix — patch bootstrap script or Sona launch alias. Dispatch Ekko if trivial.
**Refs:** `agents/evelynn/learnings/2026-04-23-sona-inbox-monitor-not-firing.md`
**Shard:** 4f8b78fd

---

## Identity leaks on work-repo PRs (Evelynn-owned fix) — RESOLVED

**Current status (2026-04-24):** PR #35 MERGED. Identity-leak fix landed (`90c830012d`). System-wide fix (subagent identity bootstrap, regex bypass for `git -c`/`git -C`, fail-closed hardening) is live. Residual: personal-scope subagent identity mis-attribution is a separate, non-blocking issue (see thread below).
**Shards:** 4f8b78fd, bd9bb7cc.
**Next:** Coordinate with Sona for company-os hook install if needed. Otherwise resolved.

---

## Slack MCP impl — SHIPPED

**Current status (2026-04-24):** PR #36 merged — custom Slack MCP migration (dual-token → single purposed-tool MCP). Strawberry sibling repo main at 2ec3f99. Plan promoted to implemented.
**Next:** None. RESOLVED.
**Refs:** `plans/implemented/personal/2026-04-24-custom-slack-mcp.md`
**Shards:** bd9bb7cc, 683a3ab7

---

## Coordinator-boot-unification — FULLY SHIPPED

**Current status (2026-04-24):** PR #39 merged (coordinator-boot.sh, stateless Monitor-arming gate). PR #40 merged (efd8be8b) — boot-unification polish: launcher headers + memory-consolidate silent-failure warn. Senna REQUEST_CHANGES → Ekko re-fix → Senna re-approve → merged. Arc complete.
**Next:** None. RESOLVED.
**Refs:** `plans/implemented/personal/2026-04-24-coordinator-boot-unification.md`
**Shards:** bd9bb7cc, 683a3ab7, 8df9ce09

---

## Resume-session coordinator-identity drift — RESOLVED

**Current status (2026-04-24):** Sona flagged via inbox (archived at agents/evelynn/inbox/archive/2026-04/20260424-0647-013277.md). Karma drafted quick-lane plan. Talon implemented. PR #41 merged (360edeb9). SessionStart source-based identity resolution live. Plan promoted to implemented at 3c1c4cde.
**Next:** None. RESOLVED.
**Shards:** 683a3ab7, 8df9ce09

---

## Personal-scope subagent identity mis-attribution — new

**Current status (2026-04-24):** Kayn's breakdown commits (and other subagent commits in personal-scope) landed as author `Orianna <orianna@strawberry.local>` due to inherited git config. Personal-scope has no identity-rewriting hook — that hook exists only for work-scope per PR #35. Not blocking. Future cleanup needed.
**Next:** Commission Ekko or Talon to add identity-rewriting hook for personal-scope subagent worktrees. Coordinate with Sona to confirm work-scope hook is sufficient for that side.
**Shard:** bd9bb7cc

---

## Orianna simplicity WARN gate — shipped

**Current status (2026-04-24):** Syndra added simplicity-first principle to Azir (via shared include) + Swain (inline). Orianna Decision-process step 6 now annotates APPROVE rationales with `WARN:` when overengineering smell detected. Committed `f8e0288`. Three plans have run through the gate cleanly (no WARN): boot-unification, custom-slack-mcp (approved + in-progress).
**Next:** Monitor in practice. No action required.
**Shard:** bd9bb7cc

---

## PR #22 — Concurrent-coordinator race closeout

**Current status (2026-04-22):** MERGED (`94c65ca`). Coordinator lock live (`149f8ac`). Ekko #53 re-sign chain still in flight at compact — body-fix committed (`fedae13`), re-sign not yet confirmed.
**Shards:** 1423e23d, ceb9f69c, f61a62e1.
**Next:** Check Ekko #53 status on resume. If stalled, use Orianna-Bypass admin path for plan → `implemented/`.

---

## Talon fast-follow — PR #22 residuals

**Current status (2026-04-22):** PR #22 merged. Plan not yet authored. I1 microsecond race, I2 PID-wrap, `$BASHPID` test tightening remain open.
**Shards:** 1423e23d, ceb9f69c.
**Next:** Commission Karma for quick-lane plan. Dispatch Talon for impl. Now durably documented in assessments/residuals-and-risks/ (one file per risk).

---

## PR #61 — Viktor S1-new-flow Wave 2

**Current status (2026-04-21):** MERGEABLE/CLEAN. Talon hotfix landed (`3995de5`) — C1 SSE auth + C2 MCP session_id validation fixed. Akali QA report at `assessments/qa-reports/2026-04-21-s1-new-flow-wave2-pr61.md`. Lucian fidelity-clean. Senna LGTM. Rule 18 now amended (PR #24) — agent can merge if checks+approval pass.
**Shards:** ef2bbc31, f61a62e1.
**Next:** Verify PR #61 still open. If checks green + Senna/Lucian approved, agent may merge directly.

---

## PR #62 — Rakan Wave 2 xfails

**Current status (2026-04-21):** Open. All F-I xfail tests authored, Senna LGTM.
**Shards:** ef2bbc31.
**Next:** Decision on resume — close-and-absorb into #61, or merge standalone.

---

## Akali live e2e QA

**Current status (2026-04-21):** In flight at compact time. Akali dispatched post-deploy against live shipped services (new revisions: S5 00006-57w, S3 00007-qjd, S1 00016-5rw).
**Shards:** ef2bbc31.
**Next:** Check Akali output on resume. Dispatch Talon for any fixes found.

---

## Swain Option B impl (vanilla Messages API)

**Current status (2026-04-21):** Plan at `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md`. 60 tasks (Aphelios), 30 test cases (Xayah), all inlined per D1A. Ready for Viktor.
**Shards:** ef2bbc31.
**Next:** Assign Viktor once ship state is stable and #61 is merged.

---

## Viktor inbox PR

**Current status (2026-04-22):** MERGED via PR #18 (`9ee2f2e`). 27/27 tests green. Closed.
**Shards:** 2cb962cd, 002efe6a, e49b10d8, 31a158e4, ef2bbc31, cea94956.
**Next:** No action. RESOLVED.

---

## Orianna-gate-speedups plan impl

**Current status (2026-04-23):** RESOLVED. Plan promoted to `implemented/` via Ekko #53 re-sign chain.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956, ceb9f69c.
**Next:** None. RESOLVED.

---

## Rule 18 — self-merge amendment

**Current status (2026-04-22):** MERGED via PR #24 (`b9e3113`). Rule 18 now permits agent self-merge when (a) all required status checks green + (b) dual approval from two non-author identities. PR #24 itself was the first use of the amended rule.
**Shards:** ceb9f69c.
**Next:** Update any delegation prompts that previously said "Duong merges only" — that constraint is gone for dual-approved PRs.

---

## Rule 16 strengthening plan — Akali + PlaywrightMCP + user-flow

**Current status (2026-04-22):** Plan authored + promoted to `approved/` (or `in-progress/`). Ekko promoting chain in flight.
**Shards:** ceb9f69c.
**Next:** Verify Ekko completed promote to `in-progress/`. Commission Talon or Akali for impl once plan is `in-progress`.

---

## Work-scope reviewer anonymity plan

**Current status (2026-04-22):** Plan authored + promoted to `approved/`; Ekko promoting chain in flight.
**Shards:** ceb9f69c.
**Next:** Verify Ekko completed promote to `in-progress/`. Commission impl agent once plan is `in-progress`.

---

## Ekko #53 re-sign chain — 3 merged plans

**Current status (2026-04-23):** RESOLVED. All three plans promoted to `implemented/`.
**Shards:** ceb9f69c.
**Next:** None. RESOLVED.

---

## Prompt-caching impl

**Current status (2026-04-22):** Boot-chain reorder **MERGED** via PR #16 (`d36b925`). Remaining Lux targets: Orianna SDK 1h TTL, agent-network.md split, subagent boot audit, instrumentation.
**Shards:** e49b10d8, 31a158e4, ef2bbc31, 2cb962cd.
**Next:** Queue Karma or direct dispatch for Lux T2-T5 (SDK TTL + agent-network split highest leverage).

---

## STAGED_SCOPE concurrent-staging fix

**Current status (2026-04-22):** MERGED via PR #20 (`e718928`). Evelynn×Sona concurrent-staging race diagnosed and fixed. STAGED_SCOPE env var now live.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956.
**Next:** Full-tree agent adoption still needed. Follow-up plan `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md` needs promotion + dispatch.

---

## Staged-scope-guard agent adoption

**Current status (2026-04-22):** PR #20 merged. Agents must adopt `STAGED_SCOPE=<files>` per-commit for the guard to enforce fully. Body-hash re-sign treadmill encountered this session — use `Orianna-Bypass` admin commit path for the promotion, not re-sign loop.
**Shards:** cea94956, 1423e23d.
**Next:** Promote via admin bypass path. Dispatch Ekko or Talon for adoption impl.

---

## Orianna rescope — substance-vs-format

**Current status (2026-04-23):** RESOLVED. Plan promoted to `implemented/` via Ekko #53 chain.
**Shards:** cea94956, ceb9f69c.
**Next:** None. RESOLVED.

---

## Rename-aware pre-lint impl

**Current status (2026-04-23):** Promoted to `plans/approved/personal/2026-04-21-pre-lint-rename-aware.md` (`8717331`). Triage's highest-priority proposed plan. Now ready for impl dispatch.
**Shards:** 31a158e4, ef2bbc31, 2cb962cd, cea94956, c95a8d3b.
**Next:** Dispatch Talon or Ekko for implementation.

---

## Commit-msg hook for AI co-author trailer — RESOLVED

**Current status (2026-04-23):** MERGED via PR #29 (`5138394`). Jayce xfail-first impl, 8/8 tests, Senna+Lucian APPROVE, self-merged. Plan promoted to `implemented/personal/` (`1ddf5c6`).
**Shards:** 69f3fb3e.
**Next:** None.

---

## Orianna v2 — simplification

**Current status (2026-04-23):** PR #30 MERGED (`add2027`). PR #31 MERGED (`34fed4b`) — physical guard / god gate live after 4 Senna review rounds (bashlex AST walker). PR #32 MERGED (`fc96916`) — agent_type identity propagation from hook JSON payload. Plan `in-progress`. Talon dispatch pending for remaining v2 tasks (~105 min). Archive semantics confirmed: old scripts → `scripts/_archive/v1-orianna-gate/`, old docs → `architecture/archive/`.
**Shards:** 69f3fb3e, 02f8c677, c95a8d3b, 26406c02.
**Next:** Dispatch Talon for remaining v2 execution tasks. Plan should promote to `implemented/` on completion.

---

## Memory-flow simplification ADR

**Current status (2026-04-23):** Promoted to `in-progress` (`c05d133` + `c13a9d5`). Xayah + Aphelios content integrated: 20 xfail tests, 59 substeps across 3 phases. Collapses 11 memory surfaces → 6, 4 close skills → 2. Retires `.remember/` for coordinators. Renames `open-threads.md` → `live-threads.md`. Fixes Sona drift bug by construction.
**Shards:** 02f8c677, c95a8d3b.
**Next:** Dispatch builder. Coordinate with Sona session before execution — touches both coordinator memory shapes. This is the highest-impact pending plan.

---

## Orianna script-path identity gap (agent_type propagation)

**Current status (2026-04-23):** PR #32 fixed identity propagation for Agent-tool-dispatched Orianna (`.agent_type` from hook JSON payload). Script-invoked worktree sessions (`.claude/worktrees/agent-*` CLI context) do NOT get `agent_type: "orianna"` populated by the runtime — gate correctly blocks them. Surfaced by subagent `a95d253d` returning BLOCKED on subagent-identity→implemented promotion.
**Shards:** 26406c02.
**Next:** Commission Swain or Azir for ADR on script-path identity propagation. Until resolved, script-dispatch Orianna promotions must use admin identity (`harukainguyen1411`) or be re-invoked via Evelynn Agent-tool dispatch.

---

## Ekko impersonation incident + plan-lifecycle-physical-guard

**Current status (2026-04-23):** RESOLVED. plan-lifecycle-physical-guard promoted to `implemented/personal/` (`dad23a3`). PR #31 (physical guard) + PR #32 (agent_type identity) both merged. Residual: script-path Orianna identity gap still open (separate thread).
**Shards:** c95a8d3b, 26406c02, ad4fe689.
**Next:** None for this incident. Script-path gap → see Orianna script-path identity gap thread.

---

## Universal worktree-isolation ADR — approved, breakdown in-flight

**Current status (2026-04-24):** Azir commissioned to author universal worktree-isolation ADR. All 4 OQs resolved by Duong: Skarner write-mode retired entirely (103dd3e), explicit merge-back helper to be included, single-PR migration ordering required. ADR promoted to `approved/` (678c971). Kayn dispatched for D1A breakdown — in-flight (see Kayn thread above).
**Next:** Check Kayn's breakdown on resume. Dispatch impl agent once breakdown reviewed.
**Shard:** 4f8b78fd

---

## Subagent-worktree-and-edit-only plan

**Current status (2026-04-24):** This plan was the precursor; universal worktree-isolation ADR (above) supersedes it in scope. Skarner write-mode now retired (103dd3e). CLAUDE.md rule 20 updated with the 4-agent opt-in list. Original plan at `plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md` may be archived once ADR impl lands.
**Next:** Archive after universal ADR impl completes.
**Shards:** c95a8d3b, 4f8b78fd.

---

## Evelynn startup parity — RESOLVED

**Current status (2026-04-23):** Shipped. Step 9 inbox scan added to Evelynn's startup sequence (`c650af8`). Both coordinators now have identical 9-step startup sequences.
**Shards:** 02f8c677.
**Next:** None. RESOLVED.

---

## Orianna-Bypass semantic gap ADR

**Current status (2026-04-21):** Open — follow-up ADR needed. Admin `--no-verify` bypass only suppresses signature hook, not structure hook. Both must be explicitly named for a complete bypass. Currently undocumented and fragile.
**Shards:** 31a158e4, ef2bbc31.
**Next:** Commission Swain or Karma for ADR consolidating admin-bypass semantics across all hooks.

---

## P2/P3/P1/P4 plan impl

**Current status (2026-04-21):** Still in proposed. Ekko #67 did not reach them. Awaiting Duong explicit call to proceed.
**Shards:** 31a158e4, ef2bbc31.
**Next:** Wait for Duong to call the shot on sequencing.

---

## 5 proposed plans awaiting Duong review (carry-forward)

**Status:** Open. Plans at `plans/proposed/personal/`: agent-feedback-system (Lux, `b9dbc8c`), retrospection-dashboard (Swain), coordinator-decision-feedback (Swain), daily-agent-repo-audit-routine (Lux), pre-orianna-plan-archive (Karma — implemented via PR #14, needs retroactive sign + promote).
**Next:** Duong reviews and approves. Use plan-promote.sh for each transition.
**Shard:** e49b10d8, 31a158e4, ef2bbc31.

---

## Memory-consolidation redesign execution

**Current status (2026-04-21):** RESOLVED — PR #13 merged. T1–T12 complete. Promoted to implemented via admin `--no-verify` (`536ec0d` + `a31cb78`). Revealed Orianna-Bypass semantic gap (sig hook only, not structure hook).
**Shards:** 2cb962cd, e49b10d8, 31a158e4.
**Next:** Dogfood in practice; flag edge cases to Swain. Follow-up ADR for bypass semantics gap.

---

## PR #15 — rule-4 staged-diff scoping fix

**Status:** MERGED at `7b3a3f3`. Closed.
**Shard:** e49b10d8, 31a158e4.

---

## PR #62 Phase 1 apps-restructure rename

**Status:** Red at last check — 4 failing checks (Lint+Build, Firebase Preview, 2× xfail-first).
**Shards:** b9780cda, 7c1cb4b8.
**Next:** Re-dispatch Viktor on branch `chore/phase1-darkstrawberry-apps-rename`. Unblock before Phase 2.

---

## Portfolio v0 importCsv export

**Status:** Open — `importCsv` HTTPS callable not exported from `apps/myapps/functions/src/index.ts`.
**Shards:** b9780cda, f62318f1, 7c1cb4b8.
**Next:** After Phase 1 rename lands, wire export + base-currency onboarding.

---

## P6 migration purge

**Status:** Gated until 2026-04-26 (7-day stability window).
**Next:** Run purge on or after 2026-04-26.

---

## Subagent permission reliability (bug #29610)

**Current status (2026-04-22):** `permissionMode: bypassPermissions` stripped from 27 agent defs (`0dcb9ba`). Per Lux research, the flag is ignored under parent `auto` mode AND implicated in Claude Code bug #29610 (background subagents terminal denial for out-of-project-root paths). Karma diagnostic plan at `plans/proposed/personal/2026-04-22-subagent-permission-reliability.md` awaits Duong's approval.
**Shards:** 2cb962cd.
**Next:** Approve Karma plan; next parallel-dispatch cluster is the live test of whether the strip holds.

---

## Rakan/Vi xfail-ownership split

**Current status (2026-04-22):** Codified across `_shared/builder.md` + `rakan.md`/`vi.md` + both coordinator CLAUDE.md files. Viktor/Jayce explicitly prohibited from writing their own xfails; Rakan (complex) and Vi (normal) own that slot, dispatched in parallel with feature builder. Quick-lane Talon stays collapsed by design.
**Shards:** 2cb962cd.
**Next:** Live-test on next standard-lane dispatch. Watch for Viktor/Jayce bypassing the rule.

---

## Reviewer-failure fallback protocol

**Current status (2026-04-22):** Codified (`1e47eda`) in both coordinator CLAUDE.md files. Reviewer writes verdict to `/tmp/<reviewer>-pr-N-verdict.md` on failure; Yuumi posts as PR comment under Duongntd (not a review — no approval claimed). Validated end-to-end on PR #16 with Lucian.
**Shards:** 2cb962cd.
**Next:** No action. Monitor for new failure modes.

---

## PAT rotation reminder

**Status:** Calendar — strawberry-reviewers PAT expires 90d from 2026-04-19 (2026-07-18).
**Next:** Duong rotates by day 80 (2026-07-08).

---

## Sona workspace staged-rename hygiene

**Status:** Open. `plans/approved/work/2026-04-20-session-state-encapsulation.md` rename is staged in Sona's concurrent workspace. Caused Senna learnings write to bounce.
**Next:** Before next Sona session, verify which branch/state is authoritative and resolve the staged rename. Do not commit to plans/approved/work/ cross-coordinator without checking first.
**Shard:** e49b10d8, 31a158e4, ef2bbc31.

---

## Agent-owned-config-flow ADR — execution

**Current status (2026-04-23):** ADR promoted to `approved/personal/` (`79981e1`). Swain rewrote against frozen deployed S2 contract (`4f88b90`). Aphelios breakdown committed inline (`4bb30da`/`2944958`).
**Shards:** ad4fe689.
**Next:** Dispatch Viktor or Jayce for implementation (D1A inline tasks available in ADR).

---

## Orianna v2 — gate-simplification plan promoted to implemented

**Current status (2026-04-23):** Plan rewritten to reflect shipped physical-guard design (`6c18579`). Promoted to `implemented/personal/` (`0314b3d`). This thread refers to the orianna-gate-simplification plan doc, not the Orianna v2 execution tasks (see Orianna v2 thread).
**Shards:** 26406c02, ad4fe689.
**Next:** None for plan doc. Orianna v2 execution (Talon) is the remaining deliverable.

---

## Trust-but-verify rule for disconfirming subagent findings

**Current status (2026-04-23):** Rule codified (`f50c173`) in both Evelynn and Sona CLAUDE.md. Triggered by Ekko-vs-deployed-S2 contract mismatch.
**Shards:** ad4fe689.
**Next:** None. Monitor for subagent result inconsistencies where the rule applies.

---

## Hands-off queue processed — 2026-04-23

**Current status (2026-04-23):** RESOLVED. 6 plans shipped to implemented, 1 to in-progress. PR #34 merged. Concurrent-agent commit entanglement pattern discovered; serialization discipline established.
**Shards:** c4af884e.
**Next:** None. RESOLVED.

---

## Three Azir ADRs awaiting Duong review

**Current status (2026-04-23):** ADRs for decision-feedback, daily-audit, and agent-feedback-system are review-ready. Awaiting Duong editorial review before promotion.
**Shards:** c4af884e.
**Next:** Duong reviews and approves. Commission implementation dispatch after approval.

---

## Plan 7 memory-flow paused-coordinator window

**Current status (2026-04-23):** Memory-flow plan (plan 7) execution requires a coordinated pause window across both coordinators. Pending Duong scheduling.
**Shards:** c4af884e.
**Next:** Duong schedules paused-coordinator window. Then dispatch builder.

---

## Plan 5 subagent-denial-probe phase-2 deferred

**Current status (2026-04-23):** Phase-1 shipped via PR #34. Phase-2 (SubagentStop wrapper for subagent-internal denial capture) deferred pending accumulation of 20+ denial rows in the probe data.
**Shards:** c4af884e.
**Next:** Monitor denial data accumulation. Dispatch phase-2 once threshold met.

---

## SessionStart:compact auto-continue — SHIPPED, plan promotion pending

**Current status (2026-04-25):** PR #46 merged (`3faa54da`). Karma quick-lane plan, Talon impl, Senna+Lucian dual approve. Replaces `Reply only:` stop directive on line 49 of `sessionstart-coordinator-identity.sh` with continue directive (scan TaskList, fall back to last-sessions/, honor pause). Fail-loud branch explicitly carves out auto-continue. Fixes the coordinator-idle-after-/compact UX bug Duong flagged.
**Next:** Orianna sweep `plans/approved/personal/2026-04-24-sessionstart-compact-auto-continue.md` → `implemented/`.
**Shards:** c1463e58, 7735fdc1

---

## SessionStart literal-sentinel fix — SHIPPED

**Current status (2026-04-25):** Shipped direct-to-main as `b6321bcd`. Fresh sessions now emit `FRESH SESSION` sentinel; both coordinators stop mistaking fresh for resumed. No observable cross-component coupling — this one was genuinely surgical. Monitor armed correctly on next session open.
**Next:** None. RESOLVED.
**Shard:** 7735fdc1

---

## Env-hygiene gate-bypass incident — REVERTED, Karma plan in flight

**Current status (2026-04-25):** Yuumi commit `240bd394` (exec-env launcher rewrite) went direct-to-main without Karma chain. Silently broke inbox-watch.sh identity resolution: Monitor-spawned subprocess does not inherit `exec env`-set vars; watcher exits 0 silently. Duong flagged with "why is starting a script so hard." Reverted as `bcbe4a3b`. Karma quick-lane plan (coordinator-identity-leak-watcher-fix) now in Orianna gating to do this properly with regression tests.
**Learning filed:** `agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md`
**Next:** Orianna approval → Talon impl → Senna+Lucian review → merge.
**Shard:** 7735fdc1

---

## Three Karma quick-lane plans — SHIPPED

**Current status (2026-04-25):** All three plans approved by Orianna and merged via Talon + dual review:
1. **worktree-hooks-propagation → PR #50 merged (`bf38b505`)** — `scripts/install-hooks.sh` now propagates hooks via `core.hooksPath`. Closes the root cause of two live bypasses (Rule 19 + identity leak).
2. **plan-lifecycle-guard-heredoc-fp → PR #52 merged (`2113ee2b`)** — bashlex AST walker tightened to file-modifying verbs only. Closes false-positive that blocked Aphelios, Sona, Lucian, Orianna.
3. **coordinator-identity-leak-watcher-fix → PR #51 merged (`5fa097ac`)** — Identity passed inline at watcher spawn; no env-var inheritance dependency. Windows `.bat` nested-quote breakage non-blocking.
**Next:** None. All three RESOLVED. Residuals: three missing block-corpus tests in #52 (Lucian, non-blocking); Windows `.bat` fix for #51 (Senna, non-blocking).
**Shard:** e7221955

---

## Worktree hooks propagation gap — RESOLVED

**Current status (2026-04-25):** PR #50 merged (`bf38b505`). `scripts/install-hooks.sh` now propagates hooks via `core.hooksPath`. Both live bypass modes closed.
**Next:** None. RESOLVED.
**Shard:** e7221955

---

## Plan-lifecycle guard heredoc fail — RESOLVED

**Current status (2026-04-25):** PR #52 merged (`2113ee2b`). AST walker now flags plan-path tokens only in file-modifying verbs. False-positive closed. Residual: three missing block-corpus tests (`eval`, `bash -c`, variable-resolution paths — Lucian non-blocking). Residual conservative-mode bypass classes noted by Senna (non-blocking follow-up hardening).
**Next:** None for the main fix. Block-corpus tests queue to Talon when capacity allows.
**Shard:** e7221955

---

## Universalise commit-time anonymity scan — pending PR #45

**Current status (2026-04-25):** Senna PR #45 architectural finding: `pre-commit-reviewer-anonymity.sh` exists but is work-scope-only (`[:/]missmp/` gate). PreToolUse was universalised in PR #45 attempts; commit-time scan wasn't. Personal-scope is one-layer-deep. Plus: human-typed `git commit` bypasses PreToolUse entirely — only the work-scope-only commit-time hook would catch that.
**Next:** Karma quick-lane plan after PR #45 settles. May fold into the pre-commit/pre-push architectural work (PR #45 Option A).
**Shard:** c1463e58

---

## Slack section deleted from duong.md

**Current status (2026-04-25):** Duong flagged the `## Slack` section as redundant with MCP tool descriptions + `.mcp.json` env vars. Verified tool schemas are self-describing (e.g. `notify_duong`: "Send a DM notification to Duong. Channel is hardcoded; no routing decision needed."). Yuumi deleted (commit `35b72641`).
**Next:** None. RESOLVED.
**Shard:** c1463e58

---

## Hands-off three-track + briefing verbosity rules added to duong.md

**Current status (2026-04-25):** Two Sona-FYI driven duong.md updates landed via Yuumi: (1) hands-off split into default/fast/slow tracks (commit `c2f9572e`), (2) briefing/status-check verbosity rule mandating signal-not-log, 3-7 bullets, surface decisions hide bookkeeping (commit `eb4adc0f`). Both apply to Evelynn + Sona.
**Next:** Internalize the verbosity rule on next session — caught violating it in this session before the rule landed.
**Shard:** c1463e58

---

## Plan-lifecycle AST scanner heredoc false-positive

**Current status (2026-04-23):** The plan-lifecycle PreToolUse AST scanner fails closed on heredoc bodies containing plan-path tokens, even when those paths appear only as string content (not as file-operation arguments). Same false-positive bit task 111 (gh pr create with plan path in commit message body).
**Shards:** c4af884e.
**Next:** Commission Karma or Talon to tighten scanner to file-modifying verbs only. Until fixed, avoid bash heredocs with plan-path strings.
