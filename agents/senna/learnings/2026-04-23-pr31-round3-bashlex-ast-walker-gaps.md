# PR #31 round-3 — bashlex AST walker closes R2 bypasses but opens 10 new ones

Session: 2026-04-23 round-3 re-review. Lane: senna (strawberry-reviewers-2). Verdict: **CHANGES_REQUESTED** (third consecutive round).

## What landed cleanly

- R2-1 (redirect-no-space), R2-2 (APFS case-fold), R2-3 (var assignment), R2-4 (ANSI-C quoting), R2-5 (fail-closed on missing python3/bashlex) — all 20 guard tests pass.
- Write/Edit/NotebookEdit branch + T7 audit unchanged from round-2 (still clean).
- Python helper: py_compile + pyflakes clean. shebang correct. stdin-based (no shell-out to bash).
- Performance ~390ms for plan-touching commands, ~130ms for fast-path. Acceptable for the risk model.

## What didn't — 10 new AST-level bypasses

All exit 0 under `CLAUDE_AGENT_NAME=ekko`, confirmed against commit `ffd5dd9`:

1. `$(cmd)` command substitution — walker never descends into WordNode.parts to reach CommandsubstitutionNode.
2. `` `cmd` `` backticks — same root cause as #1.
3. `>(cmd)` / `<(cmd)` process substitution — walker doesn't descend into ProcesssubstitutionNode even though bashlex exposes a RedirectNode inside.
4. `(cd foo && …)` subshell — CompoundNode uses `.list=[…]`, walker uses `getattr(node,'parts',[])` → empty, zero output for entire command.
5. `f() { …; }; f` function definition — FunctionNode body is a CompoundNode, same `.list` vs `.parts` bug.
6. `arr=(…)` array assignment — **bashlex parse error triggers the walker's silent fallback tokenizer** (the very mechanism round-2 said to remove). Directly undermines the AST replacement.
7. `eval "git mv src plans/approved/x.md"` — bashlex emits the whole quoted string as one WordNode.word; walker treats it as one path. No re-parse of known-eval contexts.
8. `dd of=plans/approved/x.md` — `KEY=value` prefix not stripped (unlike leading `$`).
9. `plans/{approved,proposed}/x.md` brace expansion — bashlex preserves as literal text; walker does no expansion.
10. Absolute repo-root-prefixed paths — `normalize_path` drops leading `/`, and the Bash branch doesn't strip `$REPO_ROOT/` the way Write/Edit branch does.

## Recurring lesson — the parser swap didn't fix the category

I flagged in round-2: "iterating inside the tokenizer keeps generating new rounds of escapes." Round-3 now shows that swapping to a parser generates a NEW set of rounds as you miss AST features. bashlex has roughly a dozen node kinds; the walker covers ~4 of them correctly and degrades silently on the rest. The silent tokenizer fallback (gap #6) is particularly bad — it re-introduces the round-2 failure mode under the hood.

**Structural remediations** that cut the whole family in one move (both suggested in round-2, still unclaimed):

- **Filesystem-layer ACLs on protected dirs** — `chmod +a` on macOS, `chattr +i` on Linux. Bash idioms all lose because the kernel vetoes the rename(2)/open(2) call, not a static parser.
- **Allowlist at tool level** — a dedicated `PlanMove` custom tool Orianna alone uses; every other tool (Bash, Write, Edit) is denied on these paths unconditionally. The hook's job becomes "does `tool_name == PlanMove`?" which is trivially correct.

Neither is in scope for PR #31; both belong in a follow-up plan. For this PR, fixing the tokenizer fallback (gap #6) and the walker descent gaps (#1–#5) is the minimum to merge.

## Method wins this round

- Red-team probe script — `/tmp/senna-bypass-probe.sh` — lives ~60 lines and covers 30+ shell shapes (brace, procsub, cmdsub, array, subshell, function, eval, redirect variants, APFS case, etc.). Keep this as a fixture for any future shell-idiom guard PR. Running it against the guard under test takes ~10 seconds.
- `bashlex.parse(cmd)` + `t.dump()` — invaluable for showing the author exactly what AST shape the walker is failing on. Include representative dumps in the review body, not just "bypass exists."
- Wall-time benchmark: `time (bash guard <<<payload)` — ~460ms cold. Future: if perf bites, consider a persistent Python daemon over UDS.

## Outcome

state=CHANGES_REQUESTED (third round), lane=strawberry-reviewers-2, signed `— Senna`. Counterpart Lucian's earlier rounds approved; this round I went deeper on red-teaming than he can from ADR/plan-fidelity angle. Lane separation (post-PR-45) continues to work — my CHANGES_REQUESTED is independent of Lucian's review state.
