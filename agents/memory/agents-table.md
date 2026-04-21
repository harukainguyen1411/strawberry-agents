# Agents Table

Authoritative list of agents. When adding or removing an agent, update this table in the same commit that adds/removes the agent definition file.

See `agent-network.md` for coordination rules, delegation chains, and session protocol.

Tier values: `complex` | `normal` | `quick` | `single_lane` | `concern` (coordinators)


| Agent            | Concern/Tier      | Role slot        | Pair-mate | Model       | Effort | Definition file                          | Status               |
| ---------------- | ----------------- | ---------------- | --------- | ----------- | ------ | ---------------------------------------- | -------------------- |
| **Evelynn**      | concern: personal | —                | —         | opus (omit) | medium | `.claude/agents/evelynn.md`              | active               |
| **Sona**         | concern: work     | —                | —         | opus (omit) | medium | `.claude/agents/sona.md`                 | active               |
| **Swain**        | complex           | architect        | Azir      | opus (omit) | xhigh  | `.claude/agents/swain.md`                | active               |
| **Azir**         | normal            | architect        | Swain     | opus (omit) | high   | `.claude/agents/azir.md`                 | active               |
| **Aphelios**     | complex           | breakdown        | Kayn      | opus (omit) | high   | `.claude/agents/aphelios.md`             | active               |
| **Kayn**         | normal            | breakdown        | Aphelios  | opus (omit) | medium | `.claude/agents/kayn.md`                 | active               |
| **Xayah**        | complex           | test-plan        | Caitlyn   | opus (omit) | high   | `.claude/agents/xayah.md`                | active               |
| **Caitlyn**      | normal            | test-plan        | Xayah     | opus (omit) | medium | `.claude/agents/caitlyn.md`              | active               |
| **Rakan**        | complex           | test-impl        | Vi        | sonnet      | high   | `.claude/agents/rakan.md`                | active               |
| **Vi**           | normal            | test-impl        | Rakan     | sonnet      | medium | `.claude/agents/vi.md`                   | active               |
| **Viktor**       | complex           | builder          | Jayce     | sonnet      | high   | `.claude/agents/viktor.md`               | active               |
| **Jayce**        | normal            | builder          | Viktor    | sonnet      | medium | `.claude/agents/jayce.md`                | active               |
| **Neeko**        | complex           | frontend-design  | Lulu      | opus (omit) | high   | `.claude/agents/neeko.md`                | active               |
| **Lulu**         | normal            | frontend-design  | Neeko     | opus (omit) | medium | `.claude/agents/lulu.md`                 | active               |
| **Seraphine**    | complex           | frontend-impl    | Soraka    | sonnet      | medium | `.claude/agents/seraphine.md`            | active               |
| **Soraka**       | normal            | frontend-impl    | Seraphine | sonnet      | low    | `.claude/agents/soraka.md`               | active               |
| **Lux**          | complex           | ai-specialist    | Syndra    | opus (omit) | high   | `.claude/agents/lux.md`                  | active               |
| **Syndra**       | normal            | ai-specialist    | Lux       | sonnet      | high   | `.claude/agents/syndra.md`               | active               |
| **Karma**        | quick             | quick-planner    | Talon     | opus (omit) | medium | `.claude/agents/karma.md`                | active               |
| **Talon**        | quick             | quick-executor   | Karma     | sonnet      | low    | `.claude/agents/talon.md`                | active               |
| **Heimerdinger** | single_lane       | devops-advice    | —         | opus (omit) | medium | `.claude/agents/heimerdinger.md`         | active               |
| **Ekko**         | single_lane       | devops-exec      | —         | sonnet      | medium | `.claude/agents/ekko.md`                 | active               |
| **Senna**        | single_lane       | pr-code-security | —         | opus (omit) | high   | `.claude/agents/senna.md`                | active               |
| **Lucian**       | single_lane       | pr-fidelity      | —         | opus (omit) | medium | `.claude/agents/lucian.md`               | active               |
| **Akali**        | single_lane       | qa               | —         | sonnet      | medium | `.claude/agents/akali.md`                | active               |
| **Skarner**      | single_lane       | memory           | —         | sonnet      | low    | `.claude/agents/skarner.md`              | active               |
| **Yuumi**        | single_lane       | errand           | —         | sonnet      | low    | `.claude/agents/yuumi.md`                | active               |
| **Camille**      | single_lane       | git-security     | —         | opus (omit) | medium | `.claude/agents/camille.md`              | active               |
| **Orianna**      | single_lane       | fact-check       | —         | opus (omit) | medium | `.claude/_script-only-agents/orianna.md` | active (script-only) |
| **Jhin**         | —                 | pr-review        | —         | sonnet      | —      | `.claude/_retired-agents/jhin.md`        | retired-2026-04-19   |


