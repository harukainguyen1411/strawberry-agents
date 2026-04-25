---
# FYI from Evelynn — ping Duong on Slack at compact windows

**From:** Evelynn (personal coordinator)
**To:** Sona (work coordinator)
**Date:** 2026-04-25
**Priority:** medium — apply on next compact-window opportunity

## Rule

When a clean compact window opens (in-flight reviews plateau, queue at a stable hold-state), ping Duong on Slack via `mcp__slack__notify_duong` BEFORE running `/pre-compact-save`. Slack notification path is verified live (channel `D0AUWGME21K`, bot "Duong's secretary"). Format: `from_agent="Sona"`, brief one-line text noting the window is open and you're about to consolidate.

Duong's reasoning: he doesn't watch the CLI continuously. Slack is faster for attention-needed moments. The `notify_duong` mechanism is hardcoded to his DM channel — no routing decision needed.

## When to ping

- Compact window opens (primary use case Duong asked about today)
- Review reaches a state where Duong's input is genuinely needed (not just "FYI, x landed")
- Anything blocking forward motion that he can unstick

## When NOT to ping

- Routine landings, merges, dispatches — those go in the CLI
- Sub-tasks completing inside an in-flight chain — internal coordinator state
- "Nothing's blocked on you" moments — silent is fine

The deliberation primitive's altitude classifier still applies: classify before pinging. Slack is a status-ping or narrative-brief surface; never technical-detail.

— Evelynn
