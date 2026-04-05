# Assessment: Gemini Pro — Should Duong Shift to Google's Ecosystem?

**Author:** Syndra
**Date:** 2026-04-05
**Trigger:** Duong gained access to Google Gemini Pro. Evaluate whether shifting to Google's ecosystem makes sense for the agent system.

## TL;DR

**No. Stay on Claude for agent operations. Use Gemini Pro as a supplementary tool for specific workloads where it excels (multimodal, long-context batch processing, cost-sensitive single-shot tasks). Do not migrate the agent system.**

---

## 1. Model Capabilities for Agent Work

This is the decisive factor, and it's not close.

### Where Gemini 3.1 Pro leads
- **Abstract reasoning**: 77.1% on ARC-AGI-2 vs Claude Opus 4.6's 68.8%
- **Scientific knowledge**: 94.3% on GPQA Diamond vs 91.3%
- **Multimodal processing**: Native text/image/audio/video — broader than Claude's current multimodal support
- **Context window**: 1M tokens — useful for document-heavy workloads

### Where Claude dominates (and it matters more for agents)
- **Expert agentic tasks**: Claude Opus 4.6 scores 1606 Elo on GDPval-AA; Gemini 3.1 Pro scores 1317. That's a chasm.
- **Multi-step tool use**: Gemini 3.1 Pro achieves 69.2% on MCP Atlas multi-step benchmark — meaning ~1 in 3 multi-step agent runs fail. This is disqualifying for Duong's system, which chains 5-10+ tool calls per agent turn.
- **Instruction following**: Claude's adherence to complex system prompts (CLAUDE.md, agent protocols, plan files) is materially better. Gemini tends to hallucinate its own instructions in long agentic sessions.

**Verdict:** Gemini 3.1 Pro is a strong single-shot model. It is not a reliable agent backbone. Duong's system requires agents that follow complex protocols across long sessions with dozens of tool calls. Claude is the only viable option for this.

---

## 2. Cost & Billing Implications

### Current setup
Duong runs on Claude Team plan. Agents authenticate via Claude Code's logged-in session. API keys retained only for app dev.

### Price comparison (per 1M tokens)

| Model | Input | Output |
|---|---|---|
| Claude Opus 4.6 | $5.00 | $25.00 |
| Claude Sonnet 4.6 | $3.00 | $15.00 |
| Gemini 3.1 Pro | $2.00 | $12.00 |
| Gemini Flash | ~$0.10 | ~$0.40 |

Gemini 3.1 Pro is ~40-50% cheaper than Claude equivalents. Gemini Flash is an order of magnitude cheaper for simple tasks.

### But cost isn't the bottleneck
- Duong's agent system is low-volume (personal use, not enterprise scale). The absolute dollar difference is modest.
- Claude's prompt caching (90% cheaper cached reads, automatic in Claude Code) already compresses real-world costs significantly.
- Switching to Gemini for agents to save money while losing reliability would be false economy — failed agent runs waste more money than the per-token savings.

**Verdict:** Gemini is cheaper per token, but the cost difference is not material at Duong's scale. Reliability matters more than per-token price.

---

## 3. Ecosystem & Tooling

### MCP Compatibility
- Google has announced official MCP support across Google Cloud services (Cloud Run, Storage, AlloyDB, Cloud SQL, Spanner, Looker, Pub/Sub, etc.)
- Gemini CLI supports MCP servers natively
- However, Claude Agent SDK has the deepest MCP integration. Duong's entire agent system (agent-manager MCP, evelynn MCP, custom tools) is built on Claude Code's MCP implementation.

### Migration effort
Migrating the agent system to Gemini would require:
1. **Agent protocol rewrite** — CLAUDE.md, agent-network.md, all agent profiles are tuned for Claude's instruction-following behavior
2. **MCP server adaptation** — while Gemini supports MCP, the agent-manager tooling assumes Claude Code as the runtime
3. **Session management overhaul** — heartbeat, inbox, delegation, conversation system all depend on Claude Code CLI
4. **Testing & validation** — every agent protocol would need re-validation under Gemini's different behavioral characteristics
5. **Loss of prompt caching benefits** — Claude Code's automatic caching is deeply integrated

**Estimated effort:** Weeks of work. High risk of regression. The system would be less reliable after migration given Gemini's weaker multi-step tool use.

**Verdict:** The migration cost is high and the destination is worse for this use case. Not justified.

---

## 4. Hybrid Approach — The Right Play

Instead of migrating, Gemini Pro is valuable as a **supplementary tool** for specific workloads:

### Recommended Gemini uses
| Use Case | Why Gemini | How |
|---|---|---|
| **Document analysis** | 1M context window, cheaper | Feed large docs to Gemini API for summarization/extraction |
| **Multimodal tasks** | Native audio/video processing | Image/video analysis tasks that Claude can't handle |
| **Batch classification** | Gemini Flash is extremely cheap | High-volume, low-complexity categorization tasks |
| **Personal assistant** | Already recommended Gemini Advanced for this | Life admin, learning, general queries (per AI stack assessment) |
| **Second opinion** | Different model architecture catches different things | Cross-validate Claude's outputs on critical decisions |

### What stays on Claude
| Use Case | Why Claude |
|---|---|
| **Agent system (all agents)** | Multi-step reliability, instruction following, MCP depth |
| **Code generation & review** | Claude leads on expert coding tasks |
| **Plan creation & architecture** | Complex reasoning with protocol adherence |
| **PR workflows** | Deep git/GitHub integration in Claude Code |

---

## 5. Vertex AI / Google Cloud Infrastructure

Duong doesn't currently use Google Cloud for infrastructure. Vertex AI offers:
- Managed Gemini endpoints
- Fine-tuning capabilities
- Integration with Google Cloud services

**Assessment:** Unnecessary complexity for a personal agent system. Duong's system runs locally via Claude Code CLI. Adding cloud infrastructure would increase cost, operational overhead, and latency with no clear benefit. Vertex AI is an enterprise play.

---

## Final Recommendation

| Decision | Action |
|---|---|
| **Migrate agent system to Gemini?** | **No.** Gemini's 31% multi-step failure rate is disqualifying. |
| **Add Gemini as supplementary tool?** | **Yes.** For multimodal, long-context, and batch workloads. |
| **Move to Google Cloud/Vertex AI?** | **No.** Adds complexity with no benefit at personal scale. |
| **Keep current Claude setup?** | **Yes.** Team plan + Claude Code CLI remains the right architecture. |
| **Revisit timeline** | Re-evaluate in 3 months. Gemini's agentic capabilities are improving rapidly — the 3.1 Pro was a big jump from 2.5. If multi-step reliability reaches 90%+, a hybrid agent approach becomes viable. |

The short version: Gemini Pro is a powerful model that excels at different things than Claude. Use it where it's strong. Don't force it into a role where it's weak. The agent system stays on Claude.
