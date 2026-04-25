---
title: clean-jsonl --since-last-compact slice flag
status: proposed
concern: personal
complexity: quick
orianna_gate_version: 2
owner: karma
created: 2026-04-25
tests_required: true
priority: background
---

## Context

Lissandra's `/pre-compact-save` Step 5 ("optional transcript excerpt") is silently skipped on mid-session pre-compact saves because `scripts/clean-jsonl.py` only slices whole sessions front-to-back. A pre-compact save fired between two `/compact` boundaries should excerpt only the current leg — entries since the most recent compact — so the saved excerpt mirrors the handoff shard it accompanies.

This adds a single boolean flag, `--since-last-compact`, to the existing argparse surface (around line 567). Detection looks at parsed entries for the most recent compact boundary, with two candidate markers in priority order: (1) a harness-injected `isCompactSummary: true` field on a message entry — authoritative, post-compact summary message; (2) a user message body containing `<command-name>compact</command-name>` — fallback for older transcripts predating `isCompactSummary`. The slice emits entries strictly after the latest matching marker. With multiple markers, the **last** wins (most recent leg). With no marker found and the flag set, exit non-zero with `CLEANER: no compact boundary found — session has not been compacted; rerun without --since-last-compact`. Flag absent → existing behaviour exactly.

Single-file change. Stdlib only. POSIX-portable. Background priority — parks behind cornerstone queue.

## Tasks

- T1. kind=test, estimate_minutes=20, files: `tests/scripts/test_clean_jsonl_since_last_compact.py` (new) <!-- orianna: ok -->, `tests/scripts/fixtures/` (new) <!-- orianna: ok -->. Detail: add pytest module with five fixtures-as-inline-jsonl strings (or tmp_path-written files) covering: (a) no marker + flag → non-zero exit + error substring; (b) one `isCompactSummary` mid-stream + flag → output contains only post-marker entries; (c) two `isCompactSummary` markers → slice at the **last**; (d) no `isCompactSummary` but a `<command-name>compact</command-name>` user message → boundary detected via fallback; (e) flag absent → output byte-equal to baseline run. Mark all as `@pytest.mark.xfail(reason="impl pending T2")` so CI is green pre-impl per Rule 12. Invoke `clean-jsonl.py` via `subprocess.run([sys.executable, ...])`. DoD: tests collect, all xfail, committed before T2 on the same branch.
- T2. kind=impl, estimate_minutes=25, files: `scripts/clean-jsonl.py`. Detail: (1) add `parser.add_argument("--since-last-compact", action="store_true")` next to existing flags; (2) implement `find_last_compact_index(entries) -> int | None` — scan parsed entries, return index of last entry with `entry.get("isCompactSummary") is True`; if none, scan again for user-role messages whose text content contains the literal substring `<command-name>compact</command-name>`; return the larger index of either pass, or `None`; (3) when `args.since_last_compact`, call after parse-and-flatten, before `build_output`; on `None` → `die(1, "CLEANER: no compact boundary found — session has not been compacted; rerun without --since-last-compact")`; on hit → keep only entries with index strictly greater. Remove the `xfail` markers from T1 in the same commit. DoD: all five tests pass; `--help` shows the new flag; running the script without the flag on existing fixtures produces byte-identical output to a pre-change run (manually diff once).
- T3. kind=docs, estimate_minutes=10, files: `scripts/clean-jsonl.py` (module docstring/usage block if present), `agents/lissandra/CLAUDE.md` or the `/pre-compact-save` skill markdown (whichever owns Step 5 — locate via grep for "optional transcript excerpt"). Detail: document the flag, note the priority order (`isCompactSummary` → slash-command fallback), and update Lissandra's Step 5 to actually invoke `clean-jsonl.py --since-last-compact ...` instead of skipping. DoD: skill markdown reflects new capability; no dangling "always skipped" note.

## Test plan

T1 ships all five tests as xfail. T2 flips them to passing by implementing the flag and detector. The cases protect these invariants:

- **Marker priority + recency** (cases b, c) — `isCompactSummary` is authoritative; multiple markers resolve to the last.
- **Fallback path** (case d) — pre-`isCompactSummary` transcripts still slice correctly via the slash-command form.
- **Fail-loud on missing boundary** (case a) — flag never silently emits a whole transcript; the user gets a directive error.
- **Regression guard** (case e) — flag-absent path is byte-stable; no accidental behaviour drift for existing Lissandra/Evelynn usage.

No integration test needed — single-script, stdlib-only, exercised end-to-end via subprocess in T1.

## References

- `scripts/clean-jsonl.py` (argparse around L567, `clean_chain` / `build_output` pipeline)
- `agents/evelynn/memory/last-sessions/bc09be92.md` (auth source — Lissandra `d0f20fd9` consolidation note)
- Rule 12 (xfail-first), Rule 10 (POSIX-portable — N/A here, stdlib Python)
