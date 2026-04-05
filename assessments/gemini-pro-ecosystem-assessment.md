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

---

## 6. Infrastructure Assessment: Google Cloud for the Data Layer

**Context:** Duong clarified the real question — not migrating agents off Claude, but whether Google Cloud infrastructure (Vertex AI, Cloud SQL, BigQuery, GCS) should replace the current Firebase/Firestore setup so Gemini agents can natively access the data layer. Claude stays as orchestration.

### Current Infrastructure

| Service | Purpose | Scale |
|---|---|---|
| **Firebase Auth** | Google OAuth for myapps | Single user |
| **Cloud Firestore** | User data: books, reading sessions, portfolio, goals | Small dataset (~hundreds of docs) |
| **Firebase Hosting** | myapps Vue SPA | Static site |
| **Google Analytics** | Optional metrics | Minimal |
| **Gemini API** | contributor-bot triage (via AI Studio, not Vertex) | Low volume |

Total Firebase cost at this scale: effectively **free tier** or near-zero.

### What Google Cloud Migration Would Look Like

#### Option A: Firestore → Cloud SQL (PostgreSQL)
- **What changes:** Structured relational DB instead of NoSQL documents
- **Gemini integration:** Vertex AI can ground Gemini responses against Cloud SQL via direct SQL queries or Vertex AI Extensions
- **Cost:** Cloud SQL minimum instance ~$7-10/mo (db-f1-micro). Firestore is free at this scale.
- **Migration effort:** Rewrite all Firestore queries in myapps to SQL, redesign data model from document-based to relational, update security rules to row-level security
- **Verdict:** Adds cost and complexity for data that's already well-served by Firestore

#### Option B: Add BigQuery as Analytics Layer
- **What changes:** Export Firestore data to BigQuery for analytical queries
- **Gemini integration:** BigQuery has native Gemini integration — natural language to SQL, AI-powered insights
- **Cost:** BigQuery free tier covers 1TB queries/mo and 10GB storage — more than enough
- **Use case:** "How's my reading habit trending?" / "Portfolio performance analysis" — Gemini could query BigQuery directly
- **Migration effort:** Set up Firestore→BigQuery export (built-in Firebase Extension), no app changes needed
- **Verdict:** **This is the most interesting option.** Low effort, free tier covers it, and it unlocks Gemini-powered analytics over personal data.

#### Option C: Full GCP Migration (Cloud SQL + GCS + Vertex AI)
- **What changes:** Replace Firestore with Cloud SQL, add Cloud Storage for files, run Gemini via Vertex AI instead of AI Studio
- **Cost:** $15-30/mo minimum (Cloud SQL instance + overhead). Currently ~$0.
- **Migration effort:** Significant — weeks of work rewriting myapps data layer
- **Gemini integration:** Full Vertex AI grounding, Agent Engine, RAG with personal data
- **Verdict:** Massively over-engineered for personal scale. Enterprise solution for a personal project.

#### Option D: Keep Firebase, Add Gemini via MCP (Recommended)
- **What changes:** Nothing in the infrastructure. Instead, build an MCP server that lets Claude agents (or Gemini) query Firestore directly.
- **Gemini integration:** Gemini agents access data through MCP, same as Claude agents
- **Cost:** $0 additional infrastructure cost
- **Migration effort:** Build one MCP server (~1-2 days). Firestore already has a REST API and Node.js SDK.
- **Verdict:** **Best ROI.** Keeps the working infrastructure, adds AI access to data, no vendor migration.

### Grounding with Google Search

Vertex AI offers "Grounding with Google Search" at ~$35/1,000 requests. This is irrelevant for Duong's use case — his data is private/personal, not web-searchable.

### Vertex AI Agent Engine

Google's managed agent runtime. Charges for Sessions, Memory Bank, and Code Execution. This competes with Claude Code's agent system. **Not useful** — Duong already has a working agent orchestration layer.

---

## 7. Updated Final Recommendation

| Decision | Action |
|---|---|
| **Migrate agent system to Gemini?** | **No.** Gemini's 31% multi-step failure rate is disqualifying. |
| **Replace Firestore with Cloud SQL/BigQuery?** | **No.** Current scale doesn't justify it. Firestore works and is free. |
| **Add BigQuery as analytics layer?** | **Maybe later.** Low effort via Firebase Extension, free tier. Worth doing when Duong wants AI-powered insights over personal data (reading trends, portfolio analysis). Not urgent. |
| **Full GCP migration?** | **No.** $15-30/mo for infrastructure that currently costs $0, weeks of migration work, no clear benefit. |
| **Build Firestore MCP server?** | **Yes — this is the play.** An MCP server exposing Firestore data lets any agent (Claude or Gemini) query personal data. Zero infrastructure changes, 1-2 days to build, unlocks the "Gemini accessing our data" use case without migration. |
| **Use Vertex AI?** | **No.** Gemini API via AI Studio is sufficient. Vertex adds cost and complexity for features Duong doesn't need. |
| **Keep current setup?** | **Yes.** Firebase (free tier) + Claude Code (Team plan) is the right architecture at personal scale. |

### Priority Order (if Duong wants to act)
1. **Firestore MCP server** — highest value, lowest effort. Unlocks AI queries over personal data.
2. **BigQuery export** — when analytics use cases emerge. Firebase Extension makes this trivial.
3. **Everything else** — defer until scale demands it.
