# Agent OS Unification ADR — gotchas (2026-04-20)

ADR: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os/plans/2026-04-20-agent-os-unification.md`

## Lessons for future cross-system ADRs

1. **Drift is rarely symmetric.** When auditing two parallel systems, one is almost always a strict superset of the other in infra terms, but both sides have domain data the other lacks. Here: strawberry = superset of infra (CI, scripts, invariants); workspace = superset of domain (Sona+Janna secretaries, 9 work-only agents, 40+ work plans). The ADR decision is never "keep A, discard B" — it is "keep A's infra, merge B's domain into A".

2. **Same agent name, different jobs is the worst drift.** Orianna on workspace (agent-orchestration Opus planner) and Orianna on strawberry (fact-check Sonnet gate) share nothing but the name. Catching this in the roster audit early avoided a catastrophic merge. Always diff the `description:` frontmatter field first — not just the filename.

3. **Memory merge needs a policy BEFORE you start.** Two `MEMORY.md` files with overlapping topics cannot be auto-merged safely. Surfaced this as an Open Question rather than assuming. Recommendation: preserve both under separate H2s, let the owner prune later.

4. **Context injection to subagents is NOT solved.** Claude Code's Agent tool takes a prompt string. Env vars do not reliably propagate through subagent spawn. The only bulletproof v1 mechanism is a prompt-prefix convention (`[concern: work]`) enforced by each agent's startup handshake. v2 waits for structured Agent-tool metadata.

5. **Symlink shim > clean cutover.** When migrating muscle-memory paths, resist the urge to do a clean one-shot rewrite. A `.claude/` symlink from workspace → strawberry-agents costs nothing and buys 2 weeks of grace while the user adjusts. Plan for the shim to die; plan too for the shim to live forever if it works.

6. **Concern split should only touch output artifacts.** Shared memory + shared learnings is a feature (agents accumulate knowledge). Splitting per-agent memory by concern would double write overhead and halve signal-to-noise. The discipline goes into `plans/`, `architecture/`, `assessments/` — exactly because those are where concerns actually diverge (work plans vs personal plans).

7. **Don't port CI you don't need.** Workspace has zero `.github/workflows/` at root (only in sub-repos). PR #46 adds a TDD gate at workspace root — but under unification, that gate belongs on strawberry-agents (already exists there). Closing PR #46 without merge is the right move and must be called out explicitly in §6 of any unification ADR.

8. **In-flight ADRs MUST be addressed explicitly.** Anything in flight (the three managed-agent ADRs, the Orianna port) is at risk of landing in the wrong place during migration. Listing each with a paused/re-routed/cancelled verdict is non-negotiable — otherwise they get orphaned.

## ADR-specific decisions locked in

- Strawberry version wins for all 17 overlap agents.
- Strawberry layout wins (`agents/<name>/memory/`, not `secretary/agents/<name>/memory/`).
- Strawberry universal invariants move into `architecture/personal/rules.md`; work-concern rules get their own file.
- Orianna is the fact-checker (strawberry's). Workspace Orianna dies, work-side agent-orchestration role folds into Lux.
- Sona and Janna port into strawberry-agents `.claude/agents/` as work secretaries. Evelynn stays as personal secretary.
