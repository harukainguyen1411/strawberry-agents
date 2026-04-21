# Serial dispatch for overnight autonomous sessions

**Date:** 2026-04-22
**Source:** Overnight ship session — Swain Option B vanilla-API pivot

## Learning

When operating overnight in hands-off mode with no human available to triage, use serial dispatch (one subagent at a time) even when tasks appear parallelizable. The usage ceiling — not the time available — is the primary risk in overnight sessions.

## Rationale

Parallel fan-out in a monitored session is generally correct (duong.md §50 mandate). But in an overnight autonomous session:
1. A usage spike that stalls all agents simultaneously has no human to diagnose and restart.
2. Serial dispatch converts a usage spike into a recoverable slow-down (one agent at a time, each fully completing before next dispatch).
3. The whole night is available; throughput is not the constraint.

Duong's explicit instruction: "Don't try to run everyone in parallel. You have the whole night, the thing that can stop you is you running too many subagents and blow up the usage."

## Application

- Normal sessions (Duong present): maximize parallelism per duong.md §50 mandate.
- Overnight sessions (Duong asleep, no triage available): serial dispatch. One agent. Wait for return. Synthesize. Dispatch next.
- The criterion is not task independence — it is the presence of a human who can triage a usage event.

## Companion artifact

Compass file pattern: commit a re-entry anchor document before the first overnight dispatch. Must be re-read after every auto-compact.
