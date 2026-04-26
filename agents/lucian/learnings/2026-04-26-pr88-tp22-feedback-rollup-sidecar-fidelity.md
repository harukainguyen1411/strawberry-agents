# PR #88 — T.P2.2 feedback-rollup fidelity (sidecar vs single-stream events.jsonl)

**Verdict:** APPROVE.
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/88
**Plan:** `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` §T.P2.2
**Repo:** strawberry-agents (the `tools/retro/` tree lives here, not in strawberry-app — useful to remember for future retro-dashboard reviews).

## Key decision

Plan §line 290 framed Phase 2 as "extends events.jsonl". Viktor introduced a **sidecar** `feedback-events.jsonl` instead, routed via a new SQL `-- events-source: <filename>` annotation and `resolveQueryEventsSource()` indirection in `render.mjs`. I treated this as a **drift note, not a block**, because:

1. T.P2.2's literal DoD does not mandate single-stream. It mandates source reader + mtime-cache wiring + golden — all delivered.
2. DuckDB has two real ergonomic problems with the single-stream approach: (a) schema inference confused by disjoint field sets between turn/tool_call rows and feedback-entry rows; (b) opening an empty JSONL as a database arg creates a `file` table with only a `json` column — column-not-found errors on named-column queries.
3. Phase-1 `plan-rollup.sql` filters `kind IN ('turn', 'tool_call')`, so feedback rows would be filtered out even if co-located. No semantic regression either way.
4. The `-- events-source:` annotation falls through to the Phase-1 path when absent, preserving back-compat byte-for-byte.

## Pattern: precedent-setting deviation

A single PR introducing a sidecar pattern creates **precedent for the parallel-track siblings**. T.P2.3 (decision-rollup) and T.P2.4 (coordinator-weekly) are dispatched off the same T.P2.1 base. If they don't follow the same pattern, the plan's stream-shape becomes inconsistent. I flagged this as a follow-up for the parent coordinator (Aphelios) — recommend amending §T.P2.3/T.P2.4 DoD to make the choice explicit before dispatch.

**General principle for future fan-out reviews:** when the first PR in a parallel-track triple introduces a new mechanism, ask "does this become the precedent for the other two, or is it a one-off?" — and surface it to the coordinator regardless. Cross-PR consistency is a coordinator concern but the reviewer of the first PR is the only one positioned to spot the divergence early.

## xfail-first verification

- Base SHA: `23df2e5f`. Working back via `git log --oneline <base> -- <test-path>` confirmed `53a738e` (T.P2.1 xfail bundle) added the test.
- PR head commit `c9bad65` flips it green. Single impl commit, no fixup churn — Rule 12 clean.

## Drift notes flagged but not blocking

1. `latest_entry_ts` golden format: `"2026-04-22 14:30:00"` vs fixture event ISO `"2026-04-22T14:30:00.000Z"` — DuckDB's MAX(timestamp)→VARCHAR default cast. T.P2.1 locked the golden so it's a downstream concern. T.P2.5 tile rendering will need to handle this.
2. `stateToStatus()` fallback to `'open'` on unknown values — documented as "safe default" but conflicts with the data-loss-guard preference in TP2.T4. Recommended a debug-log so typo'd states are observable.
3. `resolveQueryEventsSource()` returns null when sidecar absent → empty rollup JSON. Cold-start friendly but masks "no data ingested" vs "genuinely zero rows" — T.P2.5 should distinguish.

## Tooling notes

- `gh api repos/<owner>/<repo>/commits?path=...` requires `--method GET` style or proper URL encoding when shell-quoting; `'commits?path=...&per_page=3'` worked, bare unquoted form had zsh glob expansion issues.
- `bash scripts/reviewer-auth.sh gh ...` continues to work cleanly under `[concern: personal]`.
- The agents repo holds `tools/retro/` — not strawberry-app. Verify file path provenance before assuming repo split.
