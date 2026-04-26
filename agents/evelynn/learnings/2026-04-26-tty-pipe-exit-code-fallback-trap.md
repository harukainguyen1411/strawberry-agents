# tty-pipe-exit-code-fallback-trap

**Date:** 2026-04-26
**Discovered via:** PR #73 Senna C1 finding on `pretooluse-monitor-arming-gate.sh`

## What happened

Talon's round-1 fix for the monitor-arming-gate bugs introduced a tty-detection pattern using `tty` command exit code to decide which session key to use. When the script runs inside a pipe (the standard execution path for PreToolUse hooks), `tty` exits non-zero — meaning every non-tty subagent silently collapses to a single shared fallback key. The tty-detection branch intended to be the "fallback path" was actually the universal path in production. Senna flagged this as Critical C1.

## The trap

The fallback path (shared key) is only distinguishable from the correct path (per-session key) by reading the actual key value, not by observing behavior — subagents armed the watcher but all aimed at the same key. This is a silent correctness failure: the hook ran, returned exit 0, and the arming sentinel was written. No observable error.

## Generalizable lesson

When a conditional dispatches to a "primary path" vs "fallback path" based on a runtime probe (tty, env var presence, file existence), verify that the probe returns the *expected* value in the *actual execution environment*, not a test environment. PreToolUse hooks always run non-interactively (pipe-coupled stdin); `tty`, `[ -t 0 ]`, and `[ -t 1 ]` will always fail there. Any script that conditionally degrades based on tty detection is effectively always degraded when run as a hook.

**Rule:** For hook scripts, assume non-tty. Never make correctness depend on tty detection.
