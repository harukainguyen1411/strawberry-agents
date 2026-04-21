---
author: lux
concern: personal
date: 2026-04-21
kind: advisory-memo
status: advisory
---

# Playwright / Browser MCP survey for agent-driven UI testing

## Problem

Akali, Rakan, Vi, and Seraphine author and debug Playwright tests "blind" — reading Vue/HTML source and plans, then running the suite and eyeballing output. Need a feedback loop where an agent drives a real browser while building the test, the way a human QA engineer does.

## Ecosystem scan (2026-04 vintage)

1. **Playwright MCP (Microsoft official, `@playwright/mcp`)** — Apache-2.0, v0.0.70. Ships the MCP server (stdio/http/sse) and, added in 2026, a **Playwright CLI + Skills** mode that saves a11y snapshots/screenshots to disk — ~4x token reduction on Microsoft's own benchmarks (~114k MCP vs ~27k CLI).
2. **ExecuteAutomation `mcp-playwright`** — community fork, redundant now that Microsoft ships first-party.
3. **Browserbase + Stagehand MCP** — Apache-2.0 wrapper, v3.0.0 (Mar 2026), but **requires a Browserbase cloud account**. Infra play, not a local tool.

Not a fit: Chrome DevTools MCP (debugging/perf, not driving), `browser-use` (autonomous agent, not a test-authoring aid), hosted vendors (BrowserAct, Morph). Community has coalesced around Microsoft's server as the default.

## Capability comparison

| Capability | Playwright MCP (MS) | Playwright CLI + Skills (MS) | Browserbase MCP |
|---|---|---|---|
| Transport | stdio / http / sse | N/A (CLI + skill files) | stdio / http |
| Headless + headed | Both (`--headless` flag) | Both | Cloud-hosted (headless default) |
| Screenshot | `browser_take_screenshot` | Saved to disk | Yes |
| DOM query | `browser_snapshot` (a11y tree, ref-based, LLM-friendly — no vision model needed) | Same, persisted to disk | a11y tree |
| Network intercept | `browser_route*`, `browser_network_requests` (`--caps=network`) | Yes | Yes |
| Auth / cookies | `browser_cookie_*`, persistent profiles, storage state import/export | Yes | Yes, with session replay |
| Install | `npx @playwright/mcp@latest` | `npm i -D @playwright/test` + skill files | Cloud account + API key |
| License | Apache-2.0 | Apache-2.0 | Apache-2.0 (client) |
| Maintenance | Very active, first-party | Very active | Active |
| Token cost | High (streams a11y trees back) | Low (disk-staged) | Medium |

## Fit analysis

| Persona | Today's pain | MCP helps? | CLI + Skills helps? |
|---|---|---|---|
| **Akali** (Rule 16 QA, Figma diff, video) | Runs authored suite; can't interactively verify selectors or re-screenshot without editing test | Strong fit — drive browser live, capture ad-hoc screenshots for Figma diff report, inspect a11y snapshots for cause-of-failure | Also fits; more token-efficient for long QA sessions |
| **Rakan / Vi** (xfail + implementation) | Guess selectors from Vue source; xfail skeletons miss real DOM structure | Strong fit on **authoring** — open the surface, click to find the real `data-testid`, paste into the test | CLI + Skills is the **better** choice here — matches Claude Code's "read disk" model, 4x cheaper per task |
| **Seraphine** (FE builder) | Re-runs dev server to eyeball changes | Low-value — browser already open in dev; agent wouldn't add much vs a human tab | Skip for now |

Benefit is mostly on **authoring** (Rakan/Vi) and **QA debugging** (Akali). Not on Seraphine's implementation loop.

## Integration recommendation

**Pick (b) scoped per-agent via frontmatter — specifically, scope Playwright MCP to Akali / Rakan / Vi via the `mcpServers` frontmatter field in their `.claude/agents/*.md`.** Do **not** add to `.mcp.json`.

One-line why: the Claude Agent SDK explicitly supports `mcpServers` in subagent frontmatter and documents that inline-defined servers "keep the MCP server out of the main conversation entirely and avoid its tool descriptions consuming context there" — exactly what we need so Soraka/Syndra/Zilean spawns don't inherit a browser server they'll never touch. Reference: `code.claude.com/docs/en/sub-agents` §"Scope MCP servers to a subagent".

Two caveats to flag for Evelynn:

- **Plugin restriction** — the doc notes plugin subagents ignore `mcpServers`. Our agents live in `.claude/agents/` directly, so this is fine, but any future plugin packaging would break the scoping.
- **CLI + Skills is arguably the better long-term pick** over the MCP server for Rakan/Vi (token economics). But it's a different integration path (skill files + bash, not MCP) and belongs in a follow-up. Start with MCP, graduate to CLI if token cost becomes material.

## Concrete next steps (minimum viable add)

1. **ADR not required** — this is a per-agent tool scoping tweak, same class as adding a `tools:` allowlist. Evelynn-level approval sufficient. (If we also add to `.mcp.json`, that flips to ADR territory per `architecture/platform-parity.md` — which is a reason to stay scoped.)
2. **Files that change** (Syndra-scope — normal-track):
   - `.claude/agents/akali.md` — add `mcpServers:` block with inline `@playwright/mcp@latest` definition
   - `.claude/agents/rakan.md` — same
   - `.claude/agents/vi.md` — same
   - `agents/lux/memory/lux.md` — note the Playwright MCP pattern for future reference
3. **No env vars required** for the basic stdio install. If we want network interception, add `--caps=network` to args.
4. **Implementer**: Syndra can do this in a single PR — three frontmatter edits, no code. Not Lux-scope; I'd review the PR.
5. **Validation**: Akali runs one dry-run QA on an existing S1 surface (e.g. session page), confirms `browser_snapshot` + `browser_take_screenshot` work, then we green-light wider use.

## Sources

- [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
- [Claude Code subagents — Scope MCP servers](https://code.claude.com/docs/en/sub-agents)
- [Playwright CLI + Skills (token-efficient mode)](https://testcollab.com/blog/playwright-cli)
- [Playwright MCP vs CLI for coding agents](https://betterstack.com/community/guides/ai/playwright-cli-vs-mcp-browser/)
- [Top Playwright MCP alternatives 2026](https://mcp.directory/Blog/top-playwright-mcp-alternatives)
- [browserbase/mcp-server-browserbase](https://github.com/browserbase/mcp-server-browserbase)
- [Playwright AI ecosystem 2026](https://testdino.com/blog/playwright-ai-ecosystem/)
