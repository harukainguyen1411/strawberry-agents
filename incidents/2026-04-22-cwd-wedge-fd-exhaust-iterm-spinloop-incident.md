---
status: resolved
owner: evelynn
---

# Incident Report: Bash cwd-wedge + FD Exhaust + iTerm Spinloop Cascade — 2026-04-22

## Summary

Four compounding failures on 2026-04-22 produced a several-hour outage of the agent environment:

1. A `git mv` inside `scripts/plan-promote.sh` triggered a known upstream Claude Code bug that permanently cached a failed cwd preflight for the entire session, killing every subsequent Bash call.
2. On restart, leaked file descriptors from the broken session's subagents and MCP servers exceeded the macOS default `ulimit -n 256`, preventing `claude` from starting.
3. Over-correcting the FD limit to `INT_MAX` (2,147,483,646) caused iTerm2 to execute ~2 billion `close()` syscalls per shell spawn, pinning CPU at 91–96% and hanging all windows.
4. A misguided TCC-blame detour led to a force-quit + reinstall chain that lost custom iTerm profiles and the Pop-sound agent-message notification trigger.

A concurrent-coordinator staging stomp (Evelynn + Sona sharing working tree) amplified the damage but is addressed under a separate plan.

---

## Timeline

| Time | Event |
|---|---|
| ~13:00 | `scripts/plan-promote.sh` runs `git mv proposed → in-progress`; harness cwd preflight `stat`s repo root mid-move, gets transient failure, caches it session-wide |
| ~13:15 | Every subsequent Bash call dies: `Working directory … no longer exists. Please restart Claude from an existing directory.`; Yuumi, Azir, and Ekko subagents dispatched — all inherit broken parent state |
| ~13:30 | `/exit` + session restart attempted; `claude` refuses to start: `low max file descriptors (Unexpected)` |
| ~14:00 | `sudo launchctl limit maxfiles 524288 524288` + plist written; `ulimit -n` raised to 65536 in shell; claude restarts successfully |
| ~15:00 | iTerm2 windows begin hanging; `top` shows iTerm at 91–96% CPU |
| ~15:30 | Suspected TCC; force-quit iTerm, deleted prefs + saved state; `brew reinstall --cask iterm2` fails on sudo-prompt-in-piped-shell, stale caskroom backup, partial uninstall |
| ~15:40 | `sample <pid>` confirms 2454/2514 samples in `close()` syscall; root cause identified as `launchctl limit maxfiles 2147483646` (INT_MAX) set earlier; plist edited to 65536/65536 |
| ~15:45 | iTerm 3.6.10 clean reinstall completes; custom profiles, keybinds, and Pop-sound trigger lost |
| ~16:00 | Reboot applies plist maxfiles change; all services back to normal |

---

## Issue 1: Bash cwd-cache Wedge

### What happened

`scripts/plan-promote.sh` performs a `git mv` to move a plan file from `plans/proposed/` to `plans/in-progress/`. While the move was in flight, the Claude Code harness ran its cwd preflight `stat` on the repo root, received a transient filesystem error, and cached `WorkingDirectoryInvalid = true` for the remainder of the session. Every subsequent Bash tool call was rejected before shell spawn with:

```
Working directory /Users/duongntd99/Documents/Personal/strawberry-agents no longer exists.
Please restart Claude from an existing directory.
```

The Read tool continued to function (bypasses the cwd validator). The directory itself was fine throughout. Three subagents — Yuumi, Azir, and Ekko — were dispatched into the broken parent session and inherited the poisoned state, multiplying the blast radius.

### Root cause

Upstream Claude Code bug #29610 / filed as issue #51885 (https://github.com/anthropics/claude-code/issues/51885). The harness caches a failed cwd validation result without re-checking on subsequent calls. A transient filesystem event during a `git mv` is sufficient to trigger the cache.

### Impact

Full Bash tool loss for the session. Cascading failure across three subagent dispatches. Plan-promote work stalled until restart.

### Fix

`/exit` immediately when the cwd-wedge error appears. Do NOT dispatch subagents — they inherit the broken state. Rule committed to both coordinator CLAUDE.mds in `8e796f1`. Upstream issue filed for tracking.

---

## Issue 2: macOS `ulimit -n 256` FD Floor

### What happened

After `/exit`, leaked file descriptors from the broken session's subagents and MCP servers had not been reclaimed by the OS. The macOS default hard limit of 256 open FDs was exhausted. `claude` refused to start with `low max file descriptors (Unexpected)`.

### Root cause

macOS ships with a 256 FD default. A session with multiple subagents and MCP servers (filesystem watcher, postgres, fathom, context7) can easily hold 50–100 FDs. Three subagents that died mid-flight without clean teardown left FD table entries open in the parent process group long enough to block the next `claude` invocation.

### Impact

~30 minutes of inability to start a new claude session.

### Fix

Added `ulimit -n 65536` to `~/.zshrc` (local, not committed). Set `/Library/LaunchDaemons/limit.maxfiles.plist` to 65536/65536 (local, not committed). 65536 is sufficient for all current workloads and well within safe bounds.

---

## Issue 3: INT_MAX maxfiles → iTerm2 Spinloop

### What happened

The `low max file descriptors` error message suggested raising the limit. We raised `launchctl limit maxfiles` in steps, ultimately reaching `2147483646` (INT_MAX — the exact value the error message cited as the ceiling). iTerm2's `iTermExec` implementation does a naive `close(fd)` loop from fd 3 up to the hard limit before exec'ing each new shell. With a hard limit of INT_MAX, that is approximately 2,147,483,643 `close()` syscalls per shell spawn. iTerm pinned at 91–96% CPU. All windows hung. `sample <pid>` confirmed: 2454 of 2514 samples were inside the `close()` syscall.

### Root cause

Error-message-driven configuration. The error message named INT_MAX as the maximum valid value; we set it to that without considering O(n) startup costs in apps that loop over all possible FDs. iTerm2's pre-exec FD-closing pattern is a known performance anti-pattern when `maxfiles` is set unreasonably high.

### Impact

iTerm2 fully hung for ~30 minutes. Force-quit required. Contributed to the misguided reinstall chain (Issue 4).

### Fix

Dropped `maxfiles` to 65536/65536 via plist edit. Confirmed via `sample` that `close()` loop time became negligible. Reboot required to apply the plist change (SIP blocks live `launchctl limit` changes).

---

## Issue 4: iTerm TCC + Reinstall Chain

### What happened

While diagnosing Issue 3, iTerm's high CPU was initially misattributed to a TCC (Transparency, Consent and Control) permission failure. We force-quit iTerm, deleted `~/Library/Preferences/com.googlecode.iterm2.plist` and `~/Library/Saved Application State/com.googlecode.iterm2.savedState/`, then attempted `brew reinstall --cask iterm2`. The reinstall failed three times: sudo prompt inside a piped shell, stale caskroom backup, partial uninstall leaving dangling symlinks. A clean manual reinstall of iTerm2 3.6.10 eventually succeeded.

### Root cause

Misdiagnosis. The actual cause (INT_MAX maxfiles, confirmed later by `sample`) was not identified until after the reinstall chain was underway.

### Impact

Lost: custom iTerm profiles, keybinds, Pop-sound agent-message notification trigger. SIP blocks live `launchctl limit` changes, so the maxfiles fix only took effect after reboot.

### Fix

Pop-sound trigger recreated as a Claude Code Stop hook in `.claude/settings.local.json` (local, not committed). Custom profiles not yet restored — low priority. Rule: run `sample <pid>` before any reinstall when debugging high CPU.

---

## Issue 5: Concurrent-Coordinator Staging Stomp (Amplifier)

### What happened

Evelynn and Sona sessions were running concurrently on the shared working tree. Commit `252e024` landed with Azir's commit message on a different agent's staged diff. The `STAGED_SCOPE` env var introduced in PR #20 partially mitigates future occurrences.

### Root cause

Two coordinators writing to the same working tree simultaneously without merge-ordering. Amplified the blast radius of Issues 1–4 by interleaving partial commits during the outage window.

### Impact

One misattributed commit. No data loss.

### Fix

Concurrent-coordinator race closeout plan: `plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md` (Talon executing). Until resolved: one coordinator per working tree at a time.

---

## Lessons

1. **Never trust error-message ceiling values for system limits.** `ulimit -n 2147483646` is technically valid but catastrophic. Apps with O(n) FD startup loops (iTerm, older Python, some JVM tooling) will hang. Cap `maxfiles` at 65536 in both `~/.zshrc` and the launchd plist — that covers all real workloads.

2. **When the cwd-wedge fires, `/exit` immediately.** Do not attempt workarounds, do not dispatch subagents — they inherit the broken harness state. The only recovery is a clean session restart. This rule is now in both coordinator CLAUDE.mds (`8e796f1`).

3. **`sample <pid>` before any reinstall.** High CPU from an app is almost always diagnosable in seconds with `sample`. Reinstalling an app to fix a kernel-parameter misconfiguration wastes time and destroys config.

4. **SIP requires reboot for `launchctl limit` changes.** Plist edits alone do not apply live. Factor in a reboot window when changing system limits.

5. **One coordinator per working tree when running in parallel.** The race condition is real and produces garbled commits. Use separate worktrees or serialize coordinator sessions.

6. **Cross-reference:** `agents/evelynn/learnings/2026-04-22-maxfiles-ulimit-iterm-spinloop.md`, `agents/evelynn/inbox/archive/2026-04/2026-04-22-bash-cwd-wedge-feedback.md`.
