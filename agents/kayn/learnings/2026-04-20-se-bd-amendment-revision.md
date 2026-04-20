# 2026-04-20 — SE task file BD amendment revision

## Context

Sona produced a "BD amendment" plan file (`2026-04-20-session-state-encapsulation-bd-amendment.md`) bridging the approved SE ADR (which I decomposed earlier today, ea17448 + 36 tasks) and the newly-approved BD service-boundary ADR. The amendment names 11 specific SE task bodies that change shape and adds 1 new sub-task. My job: issue the inline task-file revision, no SE ADR rewrite.

## What I did

- Inline-edited 11 task bodies (SE.A.4, SE.A.5, SE.A.8, SE.B.2, SE.B.4, SE.C.1, SE.C.2, SE.C.3, SE.E.2, SE.F.1, SE.F.3, SE.F.5).
- Added 1 new sub-task `SE.A.4b` (agent-init metadata pass-through) preserving SE.A numbering.
- Documented a `SE.F.1b` integration-test sub-task inside SE.F.1's body (instead of creating a new section header), since the amendment §4 named it as part of SE.F.1's scope.
- Marked OQ-SE-2 as RESOLVED-then-SUPERSEDED in the Resolutions block.
- Appended a "BD amendments (Sona, 2026-04-20 s3)" section at the file end with: per-task one-line summary table, why-paragraph, out-of-scope list, cross-ADR coupling update, pointer to companion plans.
- Commit `611b52e` on `feat/demo-studio-v3`, pushed to origin. Did NOT open a PR (plans land on feature branch directly per amendment §5).

## Key calls / ambiguities resolved

1. **SE.A.7 fixture update.** Amendment §4 names SE.A.8 (impl) for the row-shape change but the xfail fixture lives in SE.A.7. The pattern from the existing file is "the impl task's amendment carries the test fixture update in the same commit pair" (see SE.A.4 amendment which does the same for SE.A.3). I documented the SE.A.7 fixture update inside SE.A.8's body rather than creating a SE.A.7b — this matches the file's existing convention. Pagination mechanism also flips from cursor → limit+offset per OQ-SE-4 resolution; I folded that into SE.A.8's "What" since it's a coupled change.

2. **SE.B.2 vs Aphelios BD task pack overlap.** `main.py` has both Refactor-to-S2 paths (4 sites BD §3.2) AND Delete-from-S1 paths (preview route, SAMPLE_CONFIG plumbing). I scoped SE.B.2 to the 4 Refactor paths only and declared the Delete-from-S1 paths as "Aphelios BD task pack scope". This avoids double-deletion when both task packs dispatch in parallel. Sona arbitrates ownership at dispatch.

3. **SE.B.4 collapses to deletion.** The amendment said "most of SE.B.4's scope collapses to deletion rather than refactor". I rewrote the task body almost wholesale: explicit delete list (map_config_to_factory_params, _build_content_from_config, prepare_demo_dict, validate_v2.py, sample-config.json) + thin pass-through shape for surviving trigger_factory* shells + status-enum normalisation slice. Flagged Aphelios overlap explicitly in the body.

4. **SE.E.2 third pattern reservation.** BD §2 Rule 4 has THREE patterns, but the amendment §4 item 8 only named TWO for SE.E.2 (config_mgmt_client scope + insuranceLine). The third (config-write `session["config"] = ...`) is in Aphelios's BD task pack per amendment §6 ("not a task breakdown"). I reserved room via the allowlist-array structure but did NOT add the third pattern speculatively, per the amendment's out-of-scope clause.

5. **SE.A.4b shortcode treatment.** The amendment §2.2 + §3 (OQ-SE-2 SUPERSEDED) explicitly says shortcode is NOT in the body. I excluded shortcode from `AgentInitMetadata` to match — even though SE.A.4b's "what" speaks generically about "agent-init metadata". Documented the exclusion in the body so the SE.F.1 implementer doesn't reintroduce it.

6. **SE.F.1b kept inside SE.F.1's body.** The user's instructions say "use SE.A.4b, SE.F.1b etc. for net-new sub-tasks" but the amendment §4 only mentions SE.F.1 explicitly (not as a separate task). I documented SE.F.1b as a labelled sub-task inside SE.F.1's "What" rather than promoting it to a top-level header. Reasoning: the verification test is intrinsic to SE.F.1's acceptance, not a separately-scheduled task; promoting it to a top-level header would inflate the task count but not the work scope. If Sona prefers a separate header, easy to lift.

## What I did NOT change

- SE.0.* (preflight) — out of scope per amendment §6.
- SE.A.1, SE.A.2, SE.A.3, SE.A.6, SE.A.7 (header), SE.A.9–13 — unchanged.
- SE.B.1, SE.B.3, SE.B.5, SE.B.6, SE.B.7, SE.B.8 — unchanged.
- SE.D.* (token TTL — tokens, not configs).
- SE.E.1 header — only SE.E.2 amended (the xfail test inside SE.E.1 needs amendment per the §6 out-of-scope clause; I noted this inside SE.E.2's body rather than editing SE.E.1 directly to stay within the §4 named-task list).
- SE.F.2, SE.F.4, SE.F.6 — unchanged (not in §4).
- SE ADR §1–§4 — never edited. Decision-of-record is the amendment file.
- OQ-SE-1, -3, -4, -5 resolutions — unchanged.

## Patterns

- **"Decision-of-record on top of an unchanged ADR"** is a useful pattern. Rather than rewriting the SE ADR (which would invalidate my 36-task decomposition + everyone else's planning artefacts), Sona produced an amendment file that names sections to read differently. Kayn implements the amendment via task-file edits + a new section pointing to the amendment. ADR diff stays small.
- **Sub-task ID convention `<parent>b`** (SE.A.4b, SE.F.1b) preserves total ordering and lets dispatch tools sort lexically. Confirmed working.
- **Fixture updates fold into the impl task's commit pair** (per the file's pre-existing TDD convention). When an amendment changes test shape, document it inside the impl task's body, not a separate xfail-amendment task.
- **Cross-ADR overlap (SE.B.2 / SE.B.4 vs Aphelios's BD task pack)** is a real coordination risk on a shared branch. Solved with explicit "this task pack owns these lines; Aphelios's pack defers" notes in the task bodies, plus a flag in the BD-amendments section for Sona to arbitrate at dispatch time.

## Estimates table left untouched

The "Estimates" table at the file's end is now inaccurate (SE.B.4 grew, SE.A added a sub-task, SE.C.1 grew). I left it alone — not in §4, and re-estimating without re-decomposing the BD ops scripts would be guessing. Flagged informally in the BD-amendments section by saying "(Total: 11 task bodies amended + 1 new sub-task ID `SE.A.4b` + 1 new sub-task `SE.F.1b` documented inside SE.F.1)". If Sona wants a re-estimate, separate ask.

## Commit + push

- Commit: `611b52e` on `feat/demo-studio-v3`.
- Pushed to `origin/feat/demo-studio-v3`. HEAD verified.
- No PR opened (plans land directly on feature branch).
- Conventional commit prefix: `chore:` (plan edit, not code).
