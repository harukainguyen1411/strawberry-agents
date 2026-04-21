# Prompt caching as the highest-ROI capacity lever

**Date:** 2026-04-21
**Source:** Lux advisory `assessments/ai-provider-capacity-expansion-2026-04-21.md`

## Finding

`cache_control: ephemeral` on stable, frequently-repeated context blocks (system prompts, `_shared/` includes, large agent definitions) gives a **90% discount** on cached input tokens. This is the single highest-ROI unexercised capacity lever in the current strawberry-agents setup — it neither requires new providers nor additional seats.

## No audit has been run yet

As of 2026-04-21, no systematic audit of which system prompts and includes are eligible for cache markers has been performed. This is identified work, not completed work.

## What to audit

- `.claude/agents/*.md` system prompts (especially coordinator definitions which are injected on every spawn)
- `_shared/` includes referenced by multiple agents
- Large plan bodies that are referenced as context in multi-turn delegation

## Caveats

- `cache_control: ephemeral` marks content as cacheable but caching only activates when the content appears at the same position in the prompt across calls. Content that changes position does not benefit.
- Cache hit rate depends on API client behavior; Claude Code's harness may not expose cache control on all injection points. Lux should verify which injection points accept the marker before the audit expands.

## Action

Assign Lux or Syndra to scope the audit. Target: identify the top 3–5 injection points by token volume that are stable across sessions. Estimate token savings and propose cache markers in a quick-lane plan if the ROI clears 30% reduction.
