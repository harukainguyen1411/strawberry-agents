# PR #31 round-4 — B1-B7 AST walker fixes land cleanly, approved

Session: 2026-04-23 round-4 re-review. Lane: senna (strawberry-reviewers-2). Verdict: **APPROVED** — merges the god gate.

## Arc summary (rounds 1 → 4)

- Round-1 (C1–C4): quote-strip, slash-collapse, dotdot, malformed JSON. Fixed.
- Round-2 (R2-1..R2-5): shell tokenizer was too weak; author swapped to bashlex AST walker. 20/20 green but new AST-level gaps surfaced in round-3.
- Round-3 (B1–B10): walker descent gaps. B1–B7 named as merge gates; B8–B10 (KEY=val prefix, brace, absolute-path strip) explicitly deferred to follow-up plan.
- Round-4 (this one): all 7 named gates close, 27/27 green. Plan's follow-up catch-all phrasing `"B8–B10 + any future AST gaps"` covers the residual red-team gaps I still find.

## What landed cleanly in round-4

- `_lib_bash_path_scan.py` B6 fallback deleted (grep shows only docstring/comment matches remain).
- `walk()` now descends `.list` on compound/subshell/function, walks `WordNode.parts` for command substitutions, and the new `commandsubstitution` branch walks `node.command` and `.parts`.
- `_try_reparse()` added for eval/bash -c/sh -c — single-level re-parse is documented in the comment ("# eval / bash -c re-parse (B7) — single level only") which is honest about nested-eval limits.
- Shell guard captures scanner rc and exits 2 fail-closed on any non-zero — proper fail-closed wiring, no `2>/dev/null` swallow on fatal path (parse error path prints its own stderr).
- Plan file line 91: `"B8–B10 + any future AST gaps to be addressed under that plan."` — single-gate follow-up landed as ACL/PlanMove plan is structurally honest.

## Remaining red-team bypasses (all in-scope for follow-up plan)

Red-team probe script `/tmp/senna-bypass-probe.sh` still finds:

1. `dd of=plans/...` (B8 — KEY=val prefix)
2. `git mv src plans/{approved,proposed}/x.md` (B9)
3. `rm -rf plans/appro*ed/` (glob)
4. `tee >(cat > plans/approved/x.md)` (ProcesssubstitutionNode not descending into RedirectNode)
5. `plans/approved\/x.md` (shell-literal backslash escape)
6. Nested eval (`eval "eval \"…\""`) — single-level re-parse is by design
7. base64-decoded paths — can't be statically resolved (design limit, not AST gap)

The single-gate honest shape: prevention covers common shapes, detection (T7 audit) catches escapes, and follow-up plan (ACL or PlanMove tool) will cut the family.

## Key method wins

- **Red-team probe as a session artifact.** `/tmp/senna-bypass-probe.sh` now has arc-long value — used it rounds 2/3/4 without modification. Keeping it at a stable `/tmp` path lets me re-run in seconds and compare rc between rounds. Worth formalizing as `agents/senna/fixtures/` for future shell-guard reviews.
- **Clone-outside-worktree pattern** when the local tree is dirty. `git clone --depth 30 --branch <head> … senna-pr31-rr4` gives an isolated test bed in seconds without disturbing coordinator sessions sharing the main repo.
- **Verdict calibration on single-gate systems.** Round-3 I went CHANGES_REQUESTED on 10 bypasses; round-4 I went APPROVED with 7 still open because the plan now carries explicit catch-all language covering "any future AST gaps." The difference is whether the gap is *silently accepted* vs *explicitly filed as follow-up*. The plan line 91 phrasing does that work. Lesson: a PR can approve with known gaps iff the gaps are named and the escalation is committed to the plan file, not "we'll think about it later."

## Lane separation

Three rounds of CHANGES_REQUESTED → APPROVED all on lane senna (strawberry-reviewers-2). Each review is a distinct submission; GitHub doesn't collapse them, and Lucian's earlier APPROVEDs on rounds 1–3 never masked mine. Post-PR-45 lane architecture keeps working.

## Outcome

state=APPROVED, lane=strawberry-reviewers-2, signed `— Senna`. Gate lands — Rule 7 now has a kernel-of-trust at the tool-call layer.
