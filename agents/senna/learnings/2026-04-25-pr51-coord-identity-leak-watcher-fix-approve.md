---
date: 2026-04-25
agent: senna
topic: PR #51 review — coordinator identity env leak + watcher subprocess fix
verdict: APPROVE (with one important nit on Windows .bat)
---

# PR #51 — coordinator identity leak + inbox-watcher Tier 3 fix

## What the PR did

- Wraps mac launcher bodies (`launch-evelynn.sh` / `launch-sona.sh`) in `( ... )` subshells so `export CLAUDE_AGENT_NAME=...` cannot leak into the sourcing shell when the script is dot-sourced.
- PowerShell variants (`.ps1`) wrap in `& { ... }` script blocks (correct equivalent).
- Adds a Tier 3 `.coordinator-identity` hint-file fallback to `inbox-watch.sh` and `inbox-watch-bootstrap.sh` so Monitor-spawned bash subprocesses can resolve identity even when env vars don't propagate.
- Extends the bootstrap source-gate from `startup`-only to `startup|resume|clear|compact` (positive allowlist as `case` block).
- Atomic `tmp+mv` write of `.coordinator-identity` from every launcher and from `coordinator-boot.sh`.
- Three new test scripts covering four regression cases (T1 leak, T2 watcher Tier 3, T3 bootstrap sources, T4 SessionStart hint-file stability).

## What I checked deeply

**The watcher-subprocess test is real** — `test-inbox-watch-tier3.sh` runs `inbox-watch.sh` in a subshell with `unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME` and only `.coordinator-identity` as identity source. That mirrors exactly the env shape Monitor's bash child sees when claude was launched via the Yuumi clean-launcher (which set env inside claude only, with no propagation to subprocesses). Test asserts `INBOX:` lines emit; if Tier 3 weren't reached, sweep wouldn't run. The fix is genuinely covered.

**Edge cases I exercised manually:**
- Stale hint pointing at non-existent agent dir → exit 0 silent (the agent-dir check at line ~73 of `inbox-watch.sh` short-circuits)
- Corrupted/garbage content → `case "$_hint" in evelynn|sona)` allowlist falls through to fail-loud
- Whitespace-padded valid name (`"  Evelynn  \n"`) → `tr -d [:space:]` normalizes correctly

## What I flagged

**Important — Windows .bat quoting:**
`launch-evelynn.bat` / `launch-sona.bat` use `cmd /c "...nested "%~dp0\..\..." and "Evelynn" inside set /p=..."` with two layers of nested double-quotes inside an outer `/C "..."`. `cmd.exe` quote-handling under `/C` is unreliable with nested quotes — likely broken on actual Windows. Recommended either dropping the outer `cmd /c` and using `setlocal`/`endlocal`, or escaping inner quotes with `^"`. The PowerShell variant is fine, so this is "important" not "critical" because most Windows users will use `.ps1`.

**Minor:** Test 3f and Test 4 build a `bash -c` command string with unquoted `$REPO/...` concatenation — works fine today, but breaks if repo lives in a path with spaces. The other test (`test-inbox-watch-tier3.sh`) already uses the cleaner `output="$( unset ...; ... bash "$REPO/..." )"` subshell pattern; same form would fix it.

**Minor:** `tr -d '[:space:]'` is permissive (strips embedded whitespace too). A user-typed hint of `"Eve lynn"` would normalize to `"evelynn"`. Hint file is launcher-written so this is not a real concern, just an observation.

## Pattern: Tier-3 hint files are the right answer for subprocess identity

Env vars set inside a long-running interactive process (claude) don't propagate to subprocesses spawned by Monitor — those subprocesses inherit claude's parent-process env, which under "clean launcher" patterns has no identity. **The canonical identity source for Monitor-spawned subprocesses is a hint file written by the launcher *before exec*.** Always pair a Tier 3 file fallback alongside Tier 1/2 env-var paths for any subprocess identity-resolution logic. The plan's architectural note nailed this lesson.

## Pattern: gate-bypass post-mortems should explicitly name the bypass

The Karma learning at `agents/karma/learnings/2026-04-25-watcher-leak-gate-bypass.md` honestly states "Yuumi's direct commit bypassed every one of these gates, which is why the regression shipped with no test coverage and was invisible until production use." This kind of explicit naming-of-the-bypass is what makes future-Karma less likely to repeat it. Useful template for future incidents.

## Verdict

APPROVE — reviewed under `strawberry-reviewers-2` (Senna lane), Lucian APPROVED separately under `strawberry-reviewers`. Both reviews posted at PR head 7ba6bb68. Rule 18 satisfied.
