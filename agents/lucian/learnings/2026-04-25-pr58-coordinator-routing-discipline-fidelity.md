# PR #58 — coordinator routing discipline fidelity (APPROVE)

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#58
**Plan:** `plans/approved/personal/2026-04-25-coordinator-routing-discipline.md` (Karma)
**Verdict:** APPROVE.

## Heuristics that fired

- **Sync-not-hand-edit verification via line-count algebra.** When a plan task says "add `<!-- include: -->` directive then run `scripts/sync-shared-rules.sh`", the cheap fidelity gate is: count the include source's lines, add 1 (for the directive), and confirm both wired def diffs net `+N+1 -0` exactly with byte-identical expanded blocks. Hand-editing produces asymmetric diffs or near-miss whitespace. Here: include = 25 lines; both wires = `+26 -0`; expanded text byte-identical between Evelynn and Sona — diagnostic of clean sync. Commit message also reports `synced=2` matching the script's output convention.
- **Sibling-primitive shape comparison.** When a plan claims a new include "mirrors" an existing one (here `coordinator-intent-check.md`), open both side by side and check: heading style, "Sourced by:" line, number/style of `##` sections, internal-only framing, exemption-block presence. Cheap and high-signal — drift in shape is structural even when content is right.
- **Three-commit-three-task plan = parent-SHA chain check.** For Karma quick-lane plans with T1-xfail / T2+T3-impl / T4+T5+T6-wire shape, just walk parent SHAs once: `gh api commits/<SHA> --jq '.parents[].sha,.files[].filename'` for each of the three commits. Confirms (a) Rule 12 ordering, (b) per-commit file scope matches task declarations, (c) no out-of-scope drift commits — all in three API calls.
- **Out-of-scope guard for "deferred-option" plans.** When a plan explicitly defers an option (here Lux's option C — PreToolUse hook), grep the diff file list for the option's expected surface (`scripts/hooks/`, `.claude/settings.json`). Absence is the gate. Cheap, definitive.

## Notes

- Talon's three commits land cleanly: parent SHAs form a clean linear chain `74d6d5c4 → a195d961 → d07c8a0d → 2f97a2ea`. xfail-first is textbook here because the plan structure forces it (T1 is its own commit by design).
- Plan `tier: quick` → impl-set `{talon}` per the new cheat-sheet §2 — this PR is itself the first artifact that the new lookup table would route. Self-consistent.
- No follow-ups. Option C deferral is the only thing the plan promises later, and it correctly lives in a different plan.

## Persistent

Add to MEMORY: **Karma quick-lane plan PRs typically present as a 3-commit chain (T1-xfail / mid-impl / final-wire-or-flip). Fidelity review collapses to three API calls (parent-SHA chain) + a line-count algebra check on any sync-script-generated diffs. Single-digit-minute review.**
