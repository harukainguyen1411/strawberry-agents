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
| **Jhin** | Sonnet | sonnet | PR reviewer | `.claude/agents/jhin.md` | `agents/jhin/` | active |
| **Seraphine** | Sonnet | sonnet | Frontend implementation — executes Neeko's design specs | `.claude/agents/seraphine.md` | `agents/seraphine/` | active |
| **Yuumi** | Sonnet | sonnet | Evelynn's errand runner | `.claude/agents/yuumi.md` | `agents/yuumi/` | active |
| **Skarner** | Sonnet | sonnet | Memory excavator — read-only searches | `.claude/agents/skarner.md` | `agents/skarner/` | promoted-from-haiku-2026-04-18 |
| **Akali** | Sonnet | sonnet | QA — Playwright flow + Figma diff before PR | `.claude/agents/akali.md` | `agents/akali/` | active |
| **Orianna** | Sonnet | sonnet | Fact-checker & memory auditor — verifies claims in plans before promotion; runs weekly memory/learnings audits | `.claude/agents/orianna.md` | `agents/orianna/` | new-2026-04-19 |
