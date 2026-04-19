# Subagent MCP auth is per-spawn + Figma Starter ceiling

**Date:** 2026-04-19 (S51)
**Context:** Portfolio v0 build. Tried to delegate Figma materialization to Neeko, hit two structural walls.

## What I learned

### 1. Subagent MCP auth is process-isolated from parent

Each subagent spawn runs its own MCP server process with its own auth state. When Duong OAuthed Figma at the top-level Evelynn session, Neeko's spawn could not see that auth — her Figma plugin was still in pre-auth state, exposing only `mcp__plugin_figma_figma__authenticate` and `_complete_authentication`, not the post-auth tools (`use_figma`, `search_design_system`, `generate_figma_design`, etc.).

This is NOT a "config persistence" issue Duong can fix at the user-global level. It's harness behavior: each subagent process is a fresh MCP client with a fresh server connection.

### 2. MCP client doesn't re-query tools/list after mid-spawn auth

Even when Neeko triggered her own `authenticate` call and Duong OAuthed her spawn directly, the post-auth tool roster did NOT appear. The MCP client snapshots its tool roster at spawn-start and doesn't re-query after auth state changes. The figma server believed auth was done; the client just never asked for the new tool list.

This made the auto-build Figma path through subagents structurally impossible in the current Claude Code harness.

### 3. Removing `tools:` from agent def = inherit all tools

Reading other agent defs (Akali pattern: no `tools:` field), I learned that omitting the `tools:` field entirely makes a subagent inherit all available tools — equivalent to general-purpose agent's `Tools: *`. This is the cleanest way to grant broad MCP access without enumerating every plugin tool. I removed Neeko's `tools:` list to give her every Figma tool that exists post-auth.

### 4. Figma Starter plan ceiling

Hit two walls building the Figma file myself (one-time Duong-authorized exception):
- **3 pages per file maximum.** I had planned 4 (Tokens, Mobile, Desktop, States) — had to fold States into Mobile.
- **MCP tool-call rate limit** triggered after ~5 `use_figma` calls in the same session. Returned a "rate limit" error pointing at the upgrade-to-Pro page. No published reset window.

The Tokens & Components page landed; Mobile and Desktop stayed empty.

## How to apply

- **Treat subagent MCP usage as one-shot per-spawn.** If a task needs MCP auth + multi-step writes, plan the entire flow inside one spawn that does its own auth, executes everything, and exits. Don't try to share auth across spawns or restart subagents expecting auth to persist.
- **For Figma writes specifically:** the path that works tonight is top-level execution (Evelynn) when Duong explicitly authorizes a coordinator-only-rule exception. For routine future work, a different design ingestion pattern is needed — possibly Duong builds Figma shells and subagents only do population passes via well-known fileKey + nodeId.
- **Pre-flight Figma jobs against the Starter ceiling.** 3 pages, low double-digit tool-calls per session. Anything bigger needs the upgrade conversation (paid; gating question per the free-tier rule).
- **Set tools: empty / removed for designer + DevOps agents.** Neeko, Ekko, possibly Akali for Playwright — they need broad tool surfaces and explicit enumeration is brittle as MCP servers add tools.
- **Do not assume subagent restart fixes the cache.** Cache is at parent-Evelynn-session level. Restart Evelynn (full /clear or quit) to flush, then spawn fresh subagents.

## Why this matters

Cost: ~30 minutes of round-trips (multiple spawn/shutdown cycles + two OAuth flows from Duong + one mid-session restart) before falling back to top-level execution. The diagnostic chain — pre-auth roster vs post-auth roster, parent OAuth vs child OAuth, cache flush behavior — is non-obvious and burned real session quota.
