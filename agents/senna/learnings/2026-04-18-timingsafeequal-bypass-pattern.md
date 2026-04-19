# Learning: timingSafeEqual defeated by short-circuit string comparison

**Date:** 2026-04-18
**Context:** PR #153 (F1 ingest token middleware)

## Pattern

```typescript
if (!timingSafeEqual(tokenBuf, expectedBuf) || token !== expected) {
```

The `|| token !== expected` branch reintroduces a variable-time string equality check.
JavaScript `!==` returns early on first mismatched character, leaking timing information
proportional to how many leading characters match. An attacker who can measure response
times can recover the token character by character despite the timingSafeEqual call.

## Correct Pattern

Use timingSafeEqual as the sole comparison. Drop the string equality bypass entirely.
Also check buffer lengths before the comparison: if input length differs from expected
length, reject before calling timingSafeEqual (or use fixed-width padding consistently
and reject inputs longer than the pad width).

## Application

Flag any `timingSafeEqual(a, b) || a !== b` pattern — the `||` fallback negates
constant-time guarantees. Also flag `Buffer.alloc(N).write(token)` without an explicit
length check for inputs exceeding N bytes.
