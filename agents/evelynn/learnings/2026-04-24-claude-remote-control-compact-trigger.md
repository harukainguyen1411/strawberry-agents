# Claude Code Remote Control resolves agent-triggered /compact need

**Date:** 2026-04-24
**Session:** 5e94cd09 (S66)
**Trigger:** Duong's research into agent-triggered /compact; Skarner confirmed no first-party mechanism existed.

## Fact

Claude Code's built-in Remote Control feature can trigger `/compact` externally. This eliminates any need for a Strawberry-side mechanism (no plan, no MCP, no hook) to initiate compact from an agent.

## Implication

Do not commission plans for "agent-triggered compact" or "scheduled compact." The capability exists natively. Skarner's prior Lux research finding ("no first-party mechanism") was accurate at research time but became moot once Duong discovered Remote Control's scope covers this case.

## Generalization

Before commissioning a plan to add infrastructure for a capability that feels like a platform gap, verify whether Claude Code's own built-in feature set (Remote Control, native hooks, etc.) already covers it. Platform capabilities evolve faster than agent memory.

**Last used:** 2026-04-24
