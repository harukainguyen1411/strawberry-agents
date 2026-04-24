# Learning: Hands-off mode + Slack-ping protocol

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard ec53a0d6)
**Concern:** work
**Severity:** medium

## What Duong directed

Late in this session, Duong formalized a new default operating mode:

1. **Hands-off is the default** from 2026-04-24 onward. Sona continues execution autonomously without waiting for Duong unless something is genuinely blocking.

2. **Slack-ping only for blocking decisions.** If Sona hits a decision only Duong can make (e.g., go-ahead for a prod deploy, approval of a plan requiring his semantic sign-off, or a security boundary call), send one ping via `mcp__slack__notify_duong`.

3. **Minimal content in pings.** The ping is an attention signal, not a report. A single sentence: "Wave D ready — need your go-ahead for the prod deploy." Duong checks the Claude session directly after the nudge.

4. **No progress reports, no completion pings.** Subagent returns, intermediate status, and non-blocking picks stay inside the Claude session. Duong reads them when he returns; no proactive notification.

## Why it matters

Prior pattern: Sona narrated heavily in inline Slack messages, including completion reports, subagent summaries, and non-blocking status. This was noise for Duong. The new protocol respects his attention budget.

## Canonical location

`agents/memory/duong.md` (Evelynn's edit); pointer in `agents/sona/CLAUDE.md` hands-off section.

## When to ping

- Wave D go-ahead needed.
- A security boundary decision only Duong can make.
- A plan approval required before any further work can proceed.
- A blocking ambiguity where proceeding incorrectly would waste significant work.

## When NOT to ping

- PR review comment posted successfully.
- Subagent returned cleanly with no blockers.
- Plan authored and awaiting Orianna gate (that's a Sona-internal step).
- Any status that can wait until Duong opens the session himself.
