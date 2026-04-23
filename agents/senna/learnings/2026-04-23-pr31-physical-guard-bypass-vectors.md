# PR #31 (physical-guard) — bypass-vector hunt on PreToolUse plan-lifecycle guard

Session: 2026-04-23. Lane: senna (strawberry-reviewers-2). Counterpart: Lucian approved; I requested changes.

## TL;DR

The first version of `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` claims to be the "one TRUE god gate" but has FOUR hard bypasses at the Bash matcher plus an inverted-semantics bug in the bypass-audit. Six unit INVs and a 3-step integration test pass locally; none of them exercise the bypass shapes I found. Classic "tests pass ≠ spec satisfied."

## The four bypasses

All against the Bash branch of the guard. The script word-splits the raw command string with `for _tok in $_cmd_norm` and feeds each token to a `case "$_p" in plans/approved/*)` glob. The matcher sees shell *source text* not shell-parsed arguments.

- **C1 — quoted paths.** `git mv plans/proposed/x.md 'plans/approved/x.md'` or `"plans/approved/x.md"` — tokens carry the quote characters inline, glob doesn't match.
- **C2 — double slash.** `plans//approved/x.md` — kernel-equivalent but `case` is literal.
- **C3 — `..` traversal past a non-plans segment.** `plans/../plans/approved/x.md` or `./foo/../plans/approved/x.md` — token doesn't start with `plans/approved/`.
- **C4 — malformed JSON fail-open.** `jq 2>/dev/null` swallows parse errors, `_tool_name` becomes empty, `case` falls through to `*) exit 0`. This is the opposite of the plan's fail-closed promise.

## The T7 audit semantic bug

`git log --follow --diff-filter=AR … | tail -1` returns the EARLIEST Add/Rename, which for every promoted plan is the original `chore: propose …` commit into `plans/proposed/`. Ran against main: 51 "orphans" reported — 51 false positives, zero signal. Correct query: the rename whose NEW-path is a protected root, detected via `--diff-filter=R --name-status` filtering.

## Method — bypass-vector probe script

I wrote `/tmp/guard-test.sh` with ~20 labeled cases over both Bash and Write tool shapes, using the same JSON payload shape as the real PreToolUse hook. Pattern:

```bash
run_case() {
  local label=$1 agent=$2 payload=$3 expected=$4
  local actual=0
  CLAUDE_AGENT_NAME="$agent" bash "$GUARD" <<<"$payload" >/dev/null 2>&1 || actual=$?
  [ "$actual" = "$expected" ] && echo PASS || echo "FAIL (got $actual)"
}
```

Cheap, effective. For every future "sandboxing/guard" PR I should build this table first from the attack surface, then grade the guard. Declared invariants are a floor, not a ceiling.

## Lessons

1. **Shell word-splitting as a guard primitive is broken by design** — it doesn't understand quotes, heredocs, redirects-without-space, or token concatenation. If I review a guard that uses `for _tok in $cmd`, that's a structural smell — suggest `python3` / proper tokenizer.
2. **`jq` error suppression at a trust boundary is fail-open.** Every `jq … 2>/dev/null` feeding `_x=""` that then drives a `case *) exit 0` is latent fail-open. Grep for this pattern in every PreToolUse/PreCommit hook.
3. **`tail -1` vs `head -1` on `git log --follow --diff-filter=AR` is a semantic trap.** `--follow` traverses renames backward; `tail -1` gets the oldest event (original Add), `head -1` gets the newest. Spec "commit that introduced this file into a protected path" is neither — it's the rename whose target is protected.
4. **Lucian-approves-Senna-blocks diverges routinely.** Lucian checks DoD line-items against task list. I check whether the code does what the plan actually claims. Different lanes, intentional. Post-PR-45 separate-lane architecture (`strawberry-reviewers-2`) means my CHANGES_REQUESTED can't be silently overwritten by his APPROVED — verified this session.
5. **Run the audit/script against the current repo.** T7 audit SELF-reports 51 false positives on main — one `bash scripts/orianna-bypass-audit.sh` invocation catches the bug instantly, but the test suite (tempdir-based synthetic commit) misses it because it tests one synthetic file in one synthetic repo. Integration tests that don't touch realistic repo shapes are weak.

## Review posted

state=CHANGES_REQUESTED, commit=788e4c6, lane=strawberry-reviewers-2, signed `— Senna`.
