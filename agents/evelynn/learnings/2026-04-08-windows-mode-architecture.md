# Windows Mode — when the right architecture is "lean substitute", not "port the existing stack"

**Date:** 2026-04-08
**Context:** Duong on a borrowed Windows laptop. Strawberry's Mac stack (iTerm dynamic profiles, MCP servers with hardcoded paths, Telegram relay, GH dual-account auth, Firebase task board) couldn't run. My first instinct was to write a plan to port everything to be cross-platform.

## What I learned

When a system is heavily coupled to one OS by design, **don't port it — write a parallel lean mode for the other OS**.

The Mac stack is load-bearing on macOS specifics. iTerm2 dynamic profiles aren't a config detail, they're the mechanism by which agents get their own terminal windows. Trying to replicate that on Windows means rebuilding the launcher from scratch, finding a Windows Terminal equivalent, gating MCP server tools per-platform, and accepting feature drift between the two OSes forever. Weeks of work, ongoing maintenance burden, and the result is two systems that almost-but-not-quite match.

The lean substitute is dramatically simpler:

- **Subagents replace iTerm windows.** Claude Code's `Agent` tool spawns agents in-process. No new terminal, no IPC, no MCP needed. Each agent's identity is preserved through files (profile, memory, last-session), exactly like the Mac iTerm versions read at startup.
- **Remote Control replaces Telegram relay.** Native Claude Code feature. Phone access via the Claude mobile app. No bot, no VPS, no token rotation, no polling loop.

Both substitutes are *better* than what they replace, not worse, for the use case of "single-user borrowed machine". And both are fully cross-platform native to Claude Code, so they require zero porting.

## The key insight that unlocked it

Duong asked: "wouldn't subagents lose their memory?" — and that's the question I should have asked myself first. The answer is no, because **Strawberry's memory was never in session state. It was always in files.** The whole agent system already reads its identity from disk on every boot — the iTerm version and the subagent version are doing the same thing. The trade-off I'd been worried about didn't exist.

**Lesson:** Before assuming a substitute architecture loses something, check whether the thing you're worried about losing actually lives where you think it does. State that's already file-based survives any change in invocation mechanism.

## When to apply this

- When porting cost > parallel-mode cost
- When the original stack depends on OS-specific primitives that have no clean cross-platform equivalent
- When the use case for the new platform is narrower than the original (e.g., "borrowed machine for solo work" vs "main daily driver with full multi-agent coordination")
- When the parallel mode can be built using native, portable primitives (here: Claude Code's own subagent + Remote Control features)

## When NOT to apply this

- When both platforms are first-class supported environments and feature drift would be a problem
- When the substitute meaningfully degrades the experience for normal use, not just edge cases
- When users would forget which mode they're in and act on the wrong assumptions

Windows Mode is acceptable because it's explicitly scoped as borrowed-machine / travel mode, with a README that lists exactly what's missing. If Duong started using it as his daily driver, drift between modes would become a real problem — but that's a future plan, not a current one.
