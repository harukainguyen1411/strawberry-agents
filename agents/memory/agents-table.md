# Agents Table

Authoritative list of agents. When adding or removing an agent, update this table in the same commit that adds/removes the agent definition file.

See `agent-network.md` for coordination rules, delegation chains, and session protocol.

| Agent | Tier | Model | Role | Definition file | Directory | Current status |
|---|---|---|---|---|---|---|
| **Evelynn** | Opus | opus | Head coordinator — routes, synthesizes, never executes | `.claude/agents/evelynn.md` | `agents/evelynn/` | active |
| **Swain** | Opus | opus | System architect — cross-cutting structural, scaling, infra planning. Do not invoke unless Duong explicitly asks. | `.claude/agents/swain.md` | — | active |
| **Azir** | Opus | opus | Head product architect — ADR plans, system architecture | `.claude/agents/azir.md` | `agents/azir/` | active |
| **Kayn** | Opus | opus | Backend task planner — breaks ADRs into executable task lists | `.claude/agents/kayn.md` | `agents/kayn/` | active |
| **Aphelios** | Opus | opus | Backend task planner — parallel partner to Kayn on large plans | `.claude/agents/aphelios.md` | `agents/aphelios/` | active |
| **Caitlyn** | Opus | opus | QA audit lead — writes testing plans, hands off to Vi | `.claude/agents/caitlyn.md` | `agents/caitlyn/` | active |
| **Lulu** | Opus | opus | Frontend/UI/UX design advisor | `.claude/agents/lulu.md` | `agents/lulu/` | active |
| **Neeko** | Opus | opus | Designer — wireframes, component specs, UI mockups, interaction flows | `.claude/agents/neeko.md` | `agents/neeko/` | active |
| **Heimerdinger** | Opus | opus | DevOps advisor — hands off execution to Ekko | `.claude/agents/heimerdinger.md` | `agents/heimerdinger/` | active |
| **Camille** | Opus | opus | Git/GitHub/security advisor | `.claude/agents/camille.md` | `agents/camille/` | active |
| **Lux** | Opus | opus | AI, Agents & MCP specialist | `.claude/agents/lux.md` | `agents/lux/` | active |
| **Jayce** | Sonnet | sonnet | Builder — new features and modules | `.claude/agents/jayce.md` | `agents/jayce/` | active |
| **Viktor** | Sonnet | sonnet | Builder — refactoring and optimization | `.claude/agents/viktor.md` | `agents/viktor/` | active |
| **Vi** | Sonnet | sonnet | Tester — executes Caitlyn's testing plans | `.claude/agents/vi.md` | `agents/vi/` | active |
| **Ekko** | Sonnet | sonnet | Quick task executor — small fixes and DevOps execution | `.claude/agents/ekko.md` | `agents/ekko/` | active |
| **Senna** | Opus | opus | PR reviewer — code quality + security | `.claude/agents/senna.md` | `agents/senna/` | active |
| **Lucian** | Opus | opus | PR reviewer — plan/ADR fidelity | `.claude/agents/lucian.md` | `agents/lucian/` | active |
| **Jhin** | Sonnet | sonnet | PR reviewer | `.claude/_retired-agents/jhin.md` | `agents/_retired/jhin/` | retired-2026-04-19 |
| **Seraphine** | Sonnet | sonnet | Frontend implementation — executes Neeko's design specs | `.claude/agents/seraphine.md` | `agents/seraphine/` | active |
| **Yuumi** | Sonnet | sonnet | Evelynn's errand runner | `.claude/agents/yuumi.md` | `agents/yuumi/` | active |
| **Skarner** | Sonnet | sonnet | Memory excavator — read-only searches | `.claude/agents/skarner.md` | `agents/skarner/` | promoted-from-haiku-2026-04-18 |
| **Akali** | Sonnet | sonnet | QA — Playwright flow + Figma diff before PR | `.claude/agents/akali.md` | `agents/akali/` | active |
| **Orianna** | Sonnet | sonnet | Fact-checker & memory auditor — verifies claims in plans before promotion; runs weekly memory/learnings audits | `.claude/agents/orianna.md` | `agents/orianna/` | new-2026-04-19 |
| **Xayah** | Opus | opus | Complex-track test planner — resilience/fault-injection/cross-service test plans and audits. Pair mate: Caitlyn. | `.claude/agents/xayah.md` | `agents/xayah/` | new-2026-04-20 |
| **Rakan** | Sonnet | sonnet | Complex-track test implementer — xfail skeletons, fault-injection harnesses, non-routine fixtures. Pair mate: Vi. | `.claude/agents/rakan.md` | `agents/rakan/` | new-2026-04-20 |
| **Soraka** | Sonnet | sonnet | Normal-track frontend implementer — small frontend tweaks from Lulu's advice. Pair mate: Seraphine. | `.claude/agents/soraka.md` | `agents/soraka/` | new-2026-04-20 |
| **Syndra** | Sonnet | sonnet | Normal-track AI/agents specialist — small AI-stack tweaks, prompt tuning, agent-def edits. Pair mate: Lux. | `.claude/agents/syndra.md` | `agents/syndra/` | new-2026-04-20 |
