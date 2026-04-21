# Ekko prompt-limit ceiling on multi-ADR signing waves

**Date:** 2026-04-21
**Session:** s2, hands-off mode

## What happened

Ekko hit the "Prompt is too long" limit twice in this session while processing signing loops across multiple ADRs:
- First crash at ~173 tool uses (session ad8cb59).
- Second crash at ~263 tool uses (session a02e809).
- Both were mid-way through signing MAD+MAL+BD in a single dispatch.

A third Ekko run (a6dbdc0) is handling SE alone — still in flight at compact boundary, managing 29 bare-module-name findings.

## The lesson

**Signing-heavy loops are context-expensive.** Each ADR signing pass involves repeated `plan-promote.sh` invocations, file reads, diff checks, and exception handling. When ≥2 ADRs are queued for signing, the context budget runs out before completion.

## The rule

**Partition signing work across multiple Ekko dispatches when >2 ADRs are in queue.** Each Ekko dispatch should target at most 2 ADRs. Provide each dispatch with: (1) the specific ADR slugs to sign, (2) the expected exception patterns (URL-shaped tokens, future-state file refs, bare-module-name findings), and (3) explicit instruction to stop and report after its batch, not attempt the full queue.

## Corollary

The four speedup options documented in `feedback/2026-04-21-orianna-signing-latency.md` address structural latency. The partition rule addresses per-dispatch context exhaustion. Both apply independently.
