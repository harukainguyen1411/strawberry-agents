# Claude Max x20 weekly Opus cap

**Date:** 2026-04-21
**Source:** Lux advisory `assessments/ai-provider-capacity-expansion-2026-04-21.md` + this session's capacity hit

## Finding

Claude Max x20 has a **weekly** Opus 4 usage cap, not just per-session or daily limits. Duong hit the cap during this session — the symptom was mid-session model degradation / refusals despite having a valid Max subscription. Purchasing a second Max seat restored capacity, confirming the bottleneck was the weekly Opus cap rather than concurrent session count or context size.

## Practical implications

1. **Run `/status` at session start for plan-authoring sessions.** If the Opus cap is near, either defer to a lighter session or switch to a Sonnet-heavy delegation strategy early, before being forced to mid-flight.
2. **More seats help only up to the point of the cap.** If both seats share the same cap envelope (unclear), the fix is temporal (wait for reset) not additive (buy more seats).
3. **Lux's identified highest-ROI lever: prompt caching.** `cache_control: ephemeral` on large system prompts and `_shared/` includes gives a 90% discount on cached input tokens. This extends effective capacity without changing the weekly ceiling.

## Lux advisory recommendation summary

- Prompt-caching audit first (zero cost, high ROI).
- Gemini Ultra as a side-channel for non-Opus-critical plan work (not as a migration target).
- Weekly Opus cap, not session count, is the binding constraint at current session volumes.
