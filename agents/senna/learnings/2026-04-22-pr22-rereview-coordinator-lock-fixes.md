# PR #22 re-review — coordinator lock fixes

Date: 2026-04-22
PR: harukainguyen1411/strawberry-agents #22 `feat/coordinator-race-closeout`
Verdict: **APPROVED** via `strawberry-reviewers-2` lane (review id 4153628476)

## Outcome

All four findings from round 1 (C1/I1/I2/S1) addressed. 9 tests green locally.
Rule 12 chain intact: `191f206` xfail precedes `60aa660` fix.

## Fix-by-fix

- **C1:** `[ -f parent ] && [ ! -d parent ]` detects worktree (where `.git` is a
  file). `git rev-parse --git-common-dir` returns absolute from worktree cwd,
  relative `.git` from main-repo cwd; latter skips the branch correctly. If
  not in a git repo, caller's `set -euo pipefail` aborts at the `exec 9<>`
  redirect — fails safe.

- **I1:** `exec 9<>"$file"` is non-truncating (directly verified). Contender
  reads the PID the holder wrote after `flock -n 9`. **Residual race**: tiny
  window between `flock` acquire and `printf PID` where contender can see
  empty → "unknown". Micro-window, not fixed.

- **I2:** `kill -0 $holder_pid` + single mkdir retry. **Latent bug**: PID wrap
  (Linux PID reuse) can leave a stale lock un-reclaimed because `kill -0`
  reports a recycled unrelated PID as alive. Low-frequency for per-repo
  scope; tighten with hostname+start-time if it bites.

- **S1:** `*"../"*|*"/.."*|".."` covers all traversal forms.

## Test-quality nits captured for future shell-test reviews

- **Pipe-RHS subshell eats variable assignments.** `cmd | { VAR="$(cat)"; ... }`
  loses VAR to the caller. Bash runs pipe components in subshells; only the
  LHS can assign if you use `lastpipe` (off by default). The I1 test had this
  bug at lines 68-73; dead code saved by a follow-up overwrite at 74-76.

- **`$$` inside `( ... )` subshells is the parent script PID, not the subshell
  PID.** When holder/contender both run under subshells of the same test
  script, both write/read the same `$$` → "exact PID match" assertions are
  trivially true. Use `$BASHPID` to exercise real-PID distinction.

- **Skip conditions need verification.** Talon's "flock not available" skip
  IS legit on stock macOS — `brew install util-linux` places flock in
  `/opt/homebrew/opt/util-linux/bin/flock`, not on default PATH. Verified by
  `command -v flock` returning not-found.

## Patterns codified

- `9<>` vs `9>`: `9>` truncates on open, `9<>` does not. When a file both
  records state AND serves as a flock target, always use `9<>`.

- `git rev-parse --git-common-dir` vs `--git-dir` vs `--absolute-git-dir`:
  from a worktree, `--git-common-dir` is the only one that gives the shared
  gitdir. From the main repo, it returns a **relative** path (`.git`), so
  always test in both locations when wiring lock paths.

- When verifying "all N tests pass", clone a fresh shallow tree and run
  end-to-end — Talon's self-report was truthful but agents should independently
  reproduce before clearing critical-security fixes.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/22#pullrequestreview-4153628476
