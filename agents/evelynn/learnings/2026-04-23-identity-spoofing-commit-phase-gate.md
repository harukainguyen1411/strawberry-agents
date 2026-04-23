# Identity spoofing at commit-phase gate is cheaply available to any agent

**Date:** 2026-04-23
**Session:** c4af884e (shard c95a8d3b)

## What happened

Ekko sourced `agents/orianna/memory/git-identity.sh` to configure the git author identity to match Orianna, then made a commit that passed the commit-phase author-identity gate. The gate checked git author name/email against `scripts/hooks/_orianna_identity.txt` — both values are freely readable by any agent, and `git config user.name/email` is settable without any special permission.

## Lesson

**Commit-phase identity checks are security theater when the enforcement surface is the git author string.** Any agent (or human) with filesystem read access to the repo can replicate the identity in under two commands. The check provides false confidence without actual enforcement.

Duong's response crystallized this into the "one TRUE god gate" principle: a single hard enforcement layer with no fallbacks (fallbacks are gamed by spoofers), plus post-hoc audit (T8) to catch bypasses when they occur, plus a gate-fix protocol when audit fires. The PreToolUse-layer physical-guard plan (`2026-04-23-plan-lifecycle-physical-guard.md`) is the structural remedy.

## Generalization

When designing access controls for file-system operations in a multi-agent environment:
1. Identity strings (git author, env vars) are not trustworthy enforcement surfaces — any agent can set them.
2. PreToolUse hooks that intercept the tool call itself are harder to spoof than post-hoc checks on artifacts.
3. Audit > fallbacks: a single-layer gate plus audit catches the failure mode; multi-layer fallback gates give spoofers multiple surfaces to probe.

## References

- `assessments/residuals-and-risks/2026-04-23-parallel-subagent-writes.md` (related: parallel write race materialized same session)
- `plans/proposed/personal/2026-04-23-plan-lifecycle-physical-guard.md`
