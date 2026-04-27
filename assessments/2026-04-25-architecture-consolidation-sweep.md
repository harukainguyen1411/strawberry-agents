# Architecture Consolidation Wave 4 — Cross-Reference Sweep Audit Log

Generated: 2026-04-27 as part of T.W4.1–T.W4.4
Plan ref: `plans/implemented/personal/2026-04-25-architecture-consolidation-v1.md`

## Source → Destination Path Map (23 moved paths)

| Old path | New path | Wave |
|---|---|---|
| `architecture/agent-pair-taxonomy.md` | `architecture/agent-network-v1/taxonomy.md` | W1A |
| `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` | W1A |
| `architecture/coordinator-boot.md` | `architecture/agent-network-v1/coordinator-boot.md` | W1A |
| `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` | W1A |
| `architecture/compact-workflow.md` | `architecture/agent-network-v1/compact-workflow.md` | W1A |
| `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` | W1A |
| `architecture/git-identity-enforcement.md` | `architecture/agent-network-v1/git-identity.md` | W1A |
| `architecture/cross-repo-workflow.md` | `architecture/agent-network-v1/cross-repo.md` | W1B |
| `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` | W1B |
| `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` | W1B |
| `architecture/platform-split.md` | `architecture/agent-network-v1/platform-split.md` | W1B |
| `architecture/plugins.md` | `architecture/agent-network-v1/plugins.md` | W1B |
| `architecture/testing.md` | `architecture/agent-network-v1/testing.md` | W1B |
| `architecture/security-debt.md` | `architecture/agent-network-v1/security-debt.md` | W1C |
| `architecture/deployment.md` | `architecture/apps/deployment.md` | W1C |
| `architecture/firebase-storage-cors.md` | `architecture/apps/firebase-storage-cors.md` | W1C |
| `architecture/system-overview.md` | `architecture/agent-network-v1/overview.md` (rewrite) + `architecture/archive/pre-network-v1/system-overview.md` | W2 |
| `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` (rewrite) + `architecture/archive/v1-orianna-gate/plan-frontmatter.md` | W2 |
| `architecture/git-workflow.md` | `architecture/agent-network-v1/git-workflow.md` (rewrite) + `architecture/archive/pre-network-v1/git-workflow.md` | W2 |
| `architecture/pr-rules.md` | `architecture/agent-network-v1/pr-rules.md` (rewrite) + `architecture/archive/pre-network-v1/pr-rules.md` | W2 |
| `architecture/infrastructure.md` | `architecture/apps/infrastructure.md` (rewrite-in-place) | W2 |
| `architecture/agent-network.md` | `architecture/archive/pre-network-v1/agent-network.md` | W3 |
| `architecture/agent-system.md` | `architecture/archive/pre-network-v1/agent-system.md` | W3 |
| `architecture/claude-billing-comparison.md` | `architecture/archive/billing-research/2026-04-05-claude-billing-comparison.md` | W3 |
| `architecture/mcp-servers.md` | `architecture/archive/pre-network-v1/mcp-servers.md` | W3 |
| `architecture/discord-relay.md` | `architecture/apps/discord-relay.md` (still in apps per current state) | W3 |
| `architecture/telegram-relay.md` | `architecture/apps/telegram-relay.md` (still in apps per current state) | W3 |
| `architecture/claude-runlock.md` | `architecture/archive/pre-network-v1/claude-runlock.md` | W3 |

## Hit List — Live Operational Files with Stale References

Files excluded from fix scope (historical records — immutable):
- `agents/*/transcripts/` — session transcripts, do not touch
- `agents/*/learnings/` — session learnings, do not touch
- `agents/*/journal/` — journals, do not touch
- `agents/_retired/*/` — retired agent memory, do not touch
- `agents/*/sessions/` and `agents/*/last-sessions/` — session shards, do not touch
- `plans/pre-orianna/` — pre-orianna historical plans, do not touch
- `plans/implemented/` — implemented plan bodies (execution records), do not touch
- `plans/archived/` — archived plan bodies, do not touch
- `scripts/_archive/` — archived scripts, do not touch

Files in scope (live operational — must fix):

### .claude/agents/ and _shared/

| File | Line | Old ref | New ref |
|---|---|---|---|
| `.claude/agents/_shared/ai-specialist.md` | 16 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `.claude/agents/_shared/architect.md` | 12 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/_shared/breakdown.md` | 12 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/_shared/coordinator-routing-check.md` | 11 | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `.claude/agents/_shared/quick-planner.md` | 12 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/aphelios.md` | 59 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/azir.md` | 46 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/evelynn.md` | 129 | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `.claude/agents/karma.md` | 54 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/kayn.md` | 59 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `.claude/agents/lux.md` | 50 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `.claude/agents/sona.md` | 129 | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `.claude/agents/syndra.md` | 69 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |

### .claude/skills/

| File | Line | Old ref | New ref |
|---|---|---|---|
| `.claude/skills/agent-ops/SKILL.md` | 88 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |

### agents/ memory and operational files

| File | Line | Old ref | New ref |
|---|---|---|---|
| `agents/aphelios/memory/MEMORY.md` | 31 | `architecture/cross-repo-workflow.md` | `architecture/agent-network-v1/cross-repo.md` |
| `agents/evelynn/CLAUDE.md` | 30 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `agents/evelynn/CLAUDE.md` | 49 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `agents/evelynn/CLAUDE.md` | 95 | `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `agents/evelynn/CLAUDE.md` | 105 | `architecture/pr-rules.md` | `architecture/agent-network-v1/pr-rules.md` |
| `agents/evelynn/memory/evelynn.md` | 200 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `agents/evelynn/memory/evelynn.md` | 457 | `architecture/git-workflow.md` | `architecture/agent-network-v1/git-workflow.md` |
| `agents/evelynn/memory/open-threads.md` | 46 | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `agents/memory/agent-network.md` | 202 | `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `agents/memory/agent-network.md` | 242 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `agents/orianna/prompts/implementation-gate-check.md` | 186 | `architecture/agent-system.md` | `architecture/archive/pre-network-v1/agent-system.md` (archived) |
| `agents/sona/CLAUDE.md` | 102 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `agents/sona/CLAUDE.md` | 151 | `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `agents/sona/inbox.md` | 24 | `architecture/agent-pair-taxonomy.md` | `architecture/agent-network-v1/taxonomy.md` |
| `agents/sona/inbox.md` | 24 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `agents/sona/inbox.md` | 49 | `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` |

### CLAUDE.md (root)

| File | Line | Old ref | New ref |
|---|---|---|---|
| `CLAUDE.md` | 11 | `architecture/compact-workflow.md` | `architecture/agent-network-v1/compact-workflow.md` |
| `CLAUDE.md` | 118 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `CLAUDE.md` | 137 | `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` |

### architecture/agent-network-v1/ internal cross-refs (residual stale refs within moved files)

| File | Line | Old ref | New ref |
|---|---|---|---|
| `architecture/agent-network-v1/coordinator-memory.md` | 130 | `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `architecture/agent-network-v1/cross-repo.md` | 117 | `architecture/pr-rules.md` | `architecture/agent-network-v1/pr-rules.md` |
| `architecture/agent-network-v1/key-scripts.md` | 3 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `architecture/agent-network-v1/key-scripts.md` | 39 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `architecture/agent-network-v1/key-scripts.md` | 57 | `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `architecture/agent-network-v1/platform-parity.md` | 27 | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `architecture/agent-network-v1/platform-parity.md` | 56 | `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` |
| `architecture/agent-network-v1/projects.md` | 157 | `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` |

### plans/approved/ (frontmatter `related:` arrays — these point to canonical docs)

| File | Old ref | New ref |
|---|---|---|
| `plans/approved/personal/2026-04-21-agent-feedback-system.md` | `architecture/agent-pair-taxonomy.md` | `architecture/agent-network-v1/taxonomy.md` |
| `plans/approved/personal/2026-04-21-agent-feedback-system.md` | `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` |
| `plans/approved/personal/2026-04-21-agent-feedback-system.md` | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `plans/approved/personal/2026-04-24-sessionstart-compact-auto-continue.md` | `architecture/compact-workflow.md` | `architecture/agent-network-v1/compact-workflow.md` |
| `plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md` | `architecture/agent-system.md` | `architecture/archive/pre-network-v1/agent-system.md` |
| `plans/approved/personal/2026-04-25-assessments-folder-structure.md` | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `plans/approved/personal/2026-04-25-coordinator-routing-discipline.md` | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `plans/approved/personal/2026-04-25-orianna-identity-protocol-alignment.md` | `architecture/git-identity-enforcement.md` | `architecture/agent-network-v1/git-identity.md` |
| `plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md` | `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` |
| `plans/approved/personal/2026-04-25-pre-dispatch-parallel-slice.md` | `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `plans/approved/personal/2026-04-25-project-based-context-doctrine.md` | `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` |
| `plans/approved/personal/2026-04-25-resolved-identity-enforcement.md` | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `plans/approved/personal/2026-04-25-resolved-identity-enforcement.md` | `architecture/git-identity-enforcement.md` | `architecture/agent-network-v1/git-identity.md` |
| `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` | `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `plans/approved/personal/2026-04-25-structured-qa-pipeline.md` | `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` |
| `plans/approved/personal/2026-04-25-structured-qa-pipeline.md` | `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |

## Fix Strategy

Apply sed-style replacements to each file. The mapping is deterministic:
- `architecture/agent-pair-taxonomy.md` → `architecture/agent-network-v1/taxonomy.md`
- `architecture/agent-routing.md` → `architecture/agent-network-v1/routing.md`
- `architecture/coordinator-boot.md` → `architecture/agent-network-v1/coordinator-boot.md`
- `architecture/coordinator-memory.md` → `architecture/agent-network-v1/coordinator-memory.md`
- `architecture/compact-workflow.md` → `architecture/agent-network-v1/compact-workflow.md`
- `architecture/plan-lifecycle.md` → `architecture/agent-network-v1/plan-lifecycle.md`
- `architecture/git-identity-enforcement.md` → `architecture/agent-network-v1/git-identity.md`
- `architecture/cross-repo-workflow.md` → `architecture/agent-network-v1/cross-repo.md`
- `architecture/key-scripts.md` → `architecture/agent-network-v1/key-scripts.md`
- `architecture/platform-parity.md` → `architecture/agent-network-v1/platform-parity.md`
- `architecture/platform-split.md` → `architecture/agent-network-v1/platform-split.md`
- `architecture/plugins.md` → `architecture/agent-network-v1/plugins.md`
- `architecture/testing.md` → `architecture/agent-network-v1/testing.md`
- `architecture/security-debt.md` → `architecture/agent-network-v1/security-debt.md`
- `architecture/deployment.md` → `architecture/apps/deployment.md`
- `architecture/firebase-storage-cors.md` → `architecture/apps/firebase-storage-cors.md`
- `architecture/infrastructure.md` → `architecture/apps/infrastructure.md`
- `architecture/system-overview.md` → `architecture/agent-network-v1/overview.md`
- `architecture/plan-frontmatter.md` → `architecture/agent-network-v1/plan-frontmatter.md`
- `architecture/git-workflow.md` → `architecture/agent-network-v1/git-workflow.md`
- `architecture/pr-rules.md` → `architecture/agent-network-v1/pr-rules.md`
- `architecture/agent-network.md` → `architecture/archive/pre-network-v1/agent-network.md`
- `architecture/agent-system.md` → `architecture/archive/pre-network-v1/agent-system.md`
