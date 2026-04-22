# maxfiles / ulimit — iTerm Spin-Loop Gotcha

**Date:** 2026-04-22

## What Happened

Setting `launchctl limit maxfiles` to `2147483646` (INT_MAX) — or even `524288` — caused iTerm to pin 96% CPU on every session spawn. Root cause: iTerm's `iTermExec` calls `close(fd)` on every fd from 3 up to the hard limit before exec'ing the shell. With INT_MAX that's ~2 billion kernel calls per spawn. Confirmed via `sample <pid>`: 2454/2514 samples were in `close()`.

## Prescription

- `ulimit -n 65536` in `~/.zshrc` — correct for shell descendants.
- `launchctl limit maxfiles 65536 65536` via `/Library/LaunchDaemons/limit.maxfiles.plist` for GUI-launched apps (incl. iTerm, Claude Code via launch services).
- Never set maxfiles to `2147483646` — many apps have O(hard_limit) startup loops, even though Apple's error message may suggest it.
- SIP blocks runtime `launchctl limit` changes — reboot required after plist edit.

## Context

- The bash-cwd wedge (upstream CC issue #51885) was what pushed us to raise maxfiles in the first place.
- Full chain in `agents/evelynn/inbox/archive/2026-04/2026-04-22-bash-cwd-wedge-feedback.md`.

## Signature

iTerm at 96% CPU on startup, `ps -o state` shows `R`, `sample` shows close-loop. Drop the FD limit — don't debug shell or prefs.

tags: ulimit, maxfiles, iterm, macos, sip, fd-exhaustion
