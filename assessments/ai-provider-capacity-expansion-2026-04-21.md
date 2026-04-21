---
title: AI provider capacity expansion — buy more Claude vs. branch out
author: Lux
date: 2026-04-21
concern: personal
status: advisory
---

# AI provider capacity expansion — assessment

Advisory only. Duong decides. No action items. Every quantitative claim is
cited with URL + fetch date; uncited claims are framed as opinion.

All URLs fetched 2026-04-21 unless otherwise noted.

## TL;DR (executive summary)

- **Current spend floor:** Claude Max 20x ($200/mo) + Claude Team 5-seat (roughly
  $150/mo base for Standard, more if any seats are Premium) — ballpark
  $350–$500/mo before overages. Actual bottleneck is almost certainly the
  weekly **Opus** cap (roughly 24–40 hours on Max 20x) plus the weekly overall
  cap, not 5-hour windows, given multi-agent orchestration.
- **Gemini Ultra ($249.99/mo) is NOT a drop-in capacity multiplier for a
  Claude-Code-style harness.** The consumer Ultra plan gives Gemini CLI
  roughly 2,000 agent requests/day (shared with Code Assist), but it does
  not unlock Vertex AI API quota; any Vertex-based agent infrastructure is
  billed per-token on top. Integration cost into the Strawberry `.claude/`
  harness is high (no drop-in equivalent of skills + `_shared/` includes +
  SessionStart hooks).
- **Strong cost lever already inside Claude:** prompt caching gives a 90%
  discount on cached input tokens. If the Strawberry harness isn't yet
  aggressively caching system prompts and `_shared/` include bodies, that
  is the single biggest quality-of-capacity win before paying for another
  provider.
- **Side-channel pattern wins short-term:** Gemini Ultra as a research /
  deep-context side-channel (1M context, Deep Research, Plan Mode in
  Gemini CLI) paired with Claude staying primary for all `.claude/agents`
  orchestration. Total: ~$600/mo for wide-context and redundancy with
  minimal integration debt.
- **"Just buy more Claude" honest answer:** a second Max 20x seat on a
  separate account, or promoting one or more Team seats to **Premium**
  (6.25× Pro usage vs. 1.25× on Standard), is likely the cheapest path to
  durable capacity if the bottleneck is weekly Sonnet/overall and not Opus.
  For Opus specifically, there is no consumer ceiling above Max 20x short
  of Enterprise (50-seat minimum, now $20/seat + metered API on top since
  the Nov 2025 repricing) — Opus overage via API-key top-up on the Max
  plan is the realistic escape valve.

---

## 1. Current-state baseline

### 1.1 What Claude Max 20x actually provides

- **Price:** $200/month for Max 20x. Nominally "20× Pro usage per session."
  [IntuitionLabs, "Claude Max Plan Explained"](https://intuitionlabs.ai/articles/claude-max-plan-pricing-usage-limits)
- **5-hour rolling window:** approximately 900 messages per 5-hour window on
  Max 20x per third-party measurement (Anthropic does not publish exact
  per-tier message numbers). Peak-hours throttle tightens this window
  (weekday 5–11am PT).
  [TechRadar on peak-hours tightening](https://www.techradar.com/ai-platforms-assistants/claude/claude-is-limiting-usage-more-aggressively-during-peak-hours-heres-what-changed)
- **Weekly caps (the real bottleneck for heavy agent use):**
  - Overall weekly cap across all models.
  - Separate weekly cap for Opus.
  - Third-party estimate for Max 20x: **240–480 hours Sonnet 4** and
    **24–40 hours Opus 4** per week, codebase-size dependent.
    [truefoundry: Claude Code Limits](https://www.truefoundry.com/blog/claude-code-limits-explained)
  - Anthropic's Nov 24 2025 announcement introduced an **independent
    Sonnet weekly limit** separate from the overall cap. The official
    help doc still conflates the two; GitHub issue
    [anthropics/claude-code#12487](https://github.com/anthropics/claude-code/issues/12487)
    tracks the ambiguity.
- **Overage behavior:** "Extra usage" is now on for paid Claude plans,
  billed at standard API rates on top of the subscription.
  [support.claude.com extra-usage article](https://support.claude.com/en/articles/12429409-manage-extra-usage-for-paid-claude-plans)
- **Peak-burn bug era:** v2.1.89-onward reports of Max 20x exhausting in
  ~70 minutes after reset are still open.
  [anthropics/claude-code#41788](https://github.com/anthropics/claude-code/issues/41788)

### 1.2 What Claude Team (5 seats) provides

- **Seat types (2026):**
  - **Standard seat:** 1.25× Pro usage per session. Single weekly cap
    across all models.
  - **Premium seat:** 6.25× Pro usage per session. Two weekly caps —
    one overall, one Sonnet-only. Both reset 7 days from session start.
  - Plans support up to 150 seats; minimum 5.
  - Per-member limits are isolated (one user hitting cap does not throttle
    others).
    [support.claude.com Team plan article](https://support.claude.com/en/articles/9266767-what-is-the-team-plan)
- **Billing:** Standard and Premium pricing is published at
  [claude.com/pricing](https://claude.com/pricing) — fetch date 2026-04-21.
  Historical tracking suggests Standard is ~$30/user/mo and Premium is
  notably higher, but exact current numbers were not verified in this
  research pass; treat as **"confirm on the pricing page before relying
  on any financial estimate"**.

### 1.3 Likely bottleneck for Duong

- Ten+ subagents orchestrated per coordinator session, several spawned
  via `run_in_background`, plus `_shared/` rule files injected into
  every agent-def → per-turn input-token footprint is large even before
  tool output. That shape stresses the **weekly overall cap** and the
  **Opus cap** far more than it stresses 5-hour windows.
- **Hypothesis, not measurement:** the pain is (a) the Opus weekly cap
  on the Max 20x personal account and (b) the 1.25× Standard-seat ceiling
  on Team seats if they are all Standard.
- **Cheap diagnostic before spending anything:** watch which cap trips
  first in `/status` across a week. If Opus trips first, more Claude
  seats don't help — only API-key overage does. If overall trips first,
  promoting Team seats to Premium is likely the cheapest fix.

---

## 2. Candidate providers

### 2.1 Google — Gemini Ultra / AI Pro / Jules / Gemini CLI

- **Pricing:**
  - **Google AI Ultra: $249.99/month** in the US (50% off for first 3
    months for first-time users).
    [gemini.google/subscriptions](https://gemini.google/subscriptions/),
    [9to5google feature matrix](https://9to5google.com/2026/04/11/google-ai-pro-ultra-features/)
  - **Google AI Pro: ~$19.99/month.**
    [costbench: Google Gemini pricing](https://costbench.com/software/ai-chatbots/gemini/)
- **What Ultra unlocks:**
  - Highest-tier access to Gemini 3 Pro, Nano Banana Pro, Veo 3.1.
  - 1M context window (roughly 1,500 pages / 30k lines of code).
  - Jules multi-agent workflow with 20× higher limits vs. Pro.
  - Highest tier of Gemini Code Assist + Gemini CLI daily requests.
  - 30 TB Google One storage (probably irrelevant for Duong).
    [9to5google article fetched 2026-04-21](https://9to5google.com/2026/04/11/google-ai-pro-ultra-features/)
- **Exact Gemini CLI / Code Assist quotas (shared across the two):**
  - Free: 1,000 requests/user/day
  - Google AI Pro: 1,500 requests/user/day
  - **Google AI Ultra: 2,000 requests/user/day**
  - Standard Edition: 1,500/day; Enterprise Edition: 2,000/day
    [developers.google.com Gemini Code Assist quotas](https://developers.google.com/gemini-code-assist/resources/quotas)
  - Consumer Ultra quota applies **only** to Gemini 2.5 Pro + Flash via
    login-based OAuth; Gemini 3 Pro usage via CLI routes through the
    API path and is **not** covered.
    [blog.google on Pro/Ultra CLI limits](https://blog.google/innovation-and-ai/technology/developers-tools/gemini-cli-code-assist-higher-limits/)
- **Critical caveat:** the consumer Ultra plan **does not apply to
  Vertex AI API quota** — if Strawberry-style agents run via Vertex
  SDK they are billed separately per-token on GCP.
  [Gemini CLI quota-and-pricing doc](https://geminicli.com/docs/resources/quota-and-pricing/),
  [oneuptime: Gemini quota management](https://oneuptime.com/blog/post/2026-02-17-how-to-manage-quotas-and-rate-limits-for-gemini-api-requests-in-vertex-ai/view)
- **MCP support:** Gemini CLI supports MCP servers (stdio + HTTP), with
  documented configuration in `~/.gemini/` and FastMCP scaffolding
  supported. Feature-wise this is the closest to parity with Claude
  Code's MCP model.
  [Gemini CLI MCP docs](https://geminicli.com/docs/tools/mcp-server/),
  [developers.googleblog: Gemini CLI + FastMCP](https://developers.googleblog.com/gemini-cli-fastmcp-simplifying-mcp-server-development/)
- **Agent-def parity:** Gemini CLI uses `AGENTS.md` / `GEMINI.md`
  convention, not the `.claude/agents/*.md` + frontmatter model.
  There is no first-class `model:` per-agent selector, no `_shared/`
  include pattern, and no SessionStart/PreCompact hook equivalents
  as of April 2026.
  [google-gemini/gemini-cli docs tree](https://github.com/google-gemini/gemini-cli)
- **Prompt caching:** Gemini has **implicit + explicit caching** with
  up to **90% discount** on cached tokens for Gemini 2.5+. Storage
  cost of ~$4.50 / 1M tokens / hour for explicit cache on Vertex.
  [Vertex context caching overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview),
  [rahulkolekar: Gemini pricing 2026](https://rahulkolekar.com/gemini-pricing-in-2026-gemini-api-vs-vertex-ai-tokens-batch-caching-imagen-veo/)
- **Known pain-point:** multiple active issues of Ultra subscribers
  still hitting low quotas on Gemini CLI.
  [google-gemini/gemini-cli#12859](https://github.com/google-gemini/gemini-cli/issues/12859)

### 2.2 OpenAI — ChatGPT Pro + Codex CLI

- **ChatGPT Pro: $200/month.** 20× higher usage than Plus.
  Unlimited GPT-5 / GPT-5.2 Pro; o3 capped at 200 messages/day and
  10 requests/minute; o4-mini capped at 2,000 messages/day.
  [help.openai.com ChatGPT Pro article](https://help.openai.com/en/articles/9793128-about-chatgpt-pro-plans),
  [IntuitionLabs: ChatGPT API pricing 2026](https://intuitionlabs.ai/articles/chatgpt-api-pricing-2026-token-costs-limits)
- **Codex CLI:**
  - Rust rewrite; faster startup; ~4× fewer tokens per task than
    Claude Code on matched benchmarks.
    [CodeAnt benchmark piece](https://www.codeant.ai/blogs/claude-code-cli-vs-codex-cli-vs-gemini-cli-best-ai-cli-tool-for-developers-in-2025)
  - Full MCP support in CLI + IDE extension. Codex itself can be
    **exposed as an MCP server** and driven by the OpenAI Agents SDK
    (`codex()` + `codex-reply()` tools).
    [OpenAI Codex MCP docs](https://developers.openai.com/codex/mcp),
    [OpenAI Codex Agents SDK guide](https://developers.openai.com/codex/guides/agents-sdk)
  - Agent-def convention is `AGENTS.md` (singular root-level file) with
    recent support for MCP server submenus and keyword install
    suggestions.
    [llmx.tech: Codex AGENTS.md + MCP setup](https://llmx.tech/blog/openai-codex-setup-agents-md-mcps-skills-definitive-guide/)
- **GCP integration:** essentially none beyond generic HTTP.
- **Switching cost from Claude Code:** high. No Skills-equivalent,
  no `_shared/` include pattern; `.claude/agents/*.md` would need to
  be flattened into a single AGENTS.md or fanned out via a home-rolled
  subagent router.

### 2.3 Cursor / Windsurf / aider

- **Cursor Pro ($20), Pro+ ($60), Ultra ($200), Teams ($40/seat).**
  [cursor.com/pricing](https://cursor.com/pricing)
- Multi-provider by design — OpenAI, Claude, Gemini all accessible
  through Cursor's credit pool. Ultra gives 20× request allowance.
  Credit cost examples (from 2025 tier data): roughly 2.4× more
  credits per Claude Sonnet request than per Gemini request.
  [DEV: Cursor Pricing in 2026](https://dev.to/rahulxsingh/cursor-pricing-in-2026-hobby-pro-pro-ultra-teams-and-enterprise-plans-explained-4b89)
- **Not a harness replacement** for Strawberry — it's an IDE
  surface, not an orchestration runtime. Useful as a second-opinion
  lane for manual coding, not for `.claude/agents/*.md` orchestration.
- aider / Windsurf similarly multi-provider, but neither currently
  ships anything resembling `_shared/` rule injection or PreCompact
  hook mechanics.

### 2.4 Claude Enterprise — the "bigger Claude" option

- **Repriced November 2025:** flat per-seat ($20/user/month) + metered
  API usage on top, instead of the prior all-inclusive ~$200/user/month
  tier that bundled tokens. Seats only (no subsidized tokens).
  [The Register: Anthropic ejects bundled tokens](https://www.theregister.com/2026/04/16/anthropic_ejects_bundled_tokens_enterprise/),
  [Let's Data Science summary](https://letsdatascience.com/news/anthropic-revises-claude-enterprise-pricing-structure-f3022a32)
- **50-seat minimum.** Not a realistic consumer option for a 1-2
  person shop.
  [support.claude.com Enterprise plan article](https://support.claude.com/en/articles/9797531-what-is-the-enterprise-plan)
- **Not useful here.** Call out only so Duong has the full shape.

---

## 3. Integration fit with Strawberry

Strawberry's Claude-Code-specific investment, mapped to each candidate:

| Feature | Claude Code (current) | Gemini CLI | Codex CLI | Cursor |
|---|---|---|---|---|
| Skill tool + `.claude/skills/*` | Native | No equivalent; manual slash commands only | No equivalent | No equivalent |
| Per-agent `.claude/agents/<name>.md` with `model:` | Native | Single `AGENTS.md` / `GEMINI.md` | Single `AGENTS.md` | No agent-def concept |
| Subagent via Agent tool + `run_in_background` | Native | Plan Mode (Mar 2026) is read-only review, not true subagent spawn | Codex-as-MCP-server can be driven by OpenAI Agents SDK — closest parity | None |
| `_shared/` include pattern via `scripts/sync-shared-rules.sh` | Custom, script-driven | No MD include; would need to re-implement | Same | Same |
| PreCompact / SessionStart hooks | Native | No hook equivalent | Limited event hooks | None |
| MCP servers (discord, gcp, etc.) | Native | Native (stdio + HTTP; FastMCP support) | Native (stdio + streaming HTTP) | Partial |
| Prompt caching (90% read discount) | Native (5-min default TTL as of 2026) | Implicit + explicit; 90% on 2.5+ | Native | N/A (Cursor fronts caching itself) |
| Settings-level permission modes | `.claude/settings.json` | `~/.gemini/` config | `~/.codex/config.toml` | Minimal |

Three honest integration postures:

1. **Full migration to Gemini CLI** — rewrite `.claude/agents/*.md` as
   a single `GEMINI.md` plus a home-rolled router. Lose skills,
   `_shared/` includes need re-implementation, hooks gone. Estimated
   effort: weeks of non-value-adding re-platforming. **Don't.**
2. **Parallel lane** — Claude Code stays canonical; Gemini CLI hosts
   a separate set of non-critical roles (e.g., a Gemini-powered
   "research scout" that lives alongside Lux but owns no plan-promotion
   or implementation paths). MCP servers that are already HTTP-reachable
   (gcp, postgres) can be shared across both CLIs trivially. Agent
   defs stay Claude-only. Estimated effort: days, not weeks.
3. **Supplementary side-channel** — Gemini Ultra used entirely outside
   the `.claude/` harness, via the Gemini web app, Jules, Deep Research,
   and the occasional `gemini` CLI invocation for 1M-context queries.
   No agent-def work required. Cheapest integration cost. **Strongly
   recommended as the default first step.**

---

## 4. Google Cloud affinity

- **Vertex AI Agent Builder + ADK (April 2026):** production-ready.
  ADK is model-agnostic but Gemini-optimized; `adk deploy` ships agents
  to the Agent Engine managed runtime. ADK has had 7M+ downloads since
  launch.
  [cloud.google.com Agent Builder product page](https://cloud.google.com/products/agent-builder),
  [cloud.google.com blog: more ways to build agents](https://cloud.google.com/blog/products/ai-machine-learning/more-ways-to-build-and-scale-ai-agents-with-vertex-ai-agent-builder)
- **Vertex vs. Ultra quota relationship:** **separate**. Consumer AI
  Ultra applies to Gemini web app + Flow + login-based Gemini CLI
  using 2.5 Pro/Flash. Vertex AI usage is Standard PayGo and is
  billed per-token on the existing GCP account, with prepay credits
  locked to Gemini API only.
  [Vertex AI pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing),
  [Vertex generative AI quotas](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/quotas)
- **Bundling upside:** if Duong already has sustained GCP spend
  (Cloud Run, GCS, Firestore per existing plans), Vertex Gemini
  usage lands on the same bill and can benefit from committed-use
  discounts and existing credits, which ChatGPT / Claude API cannot.
  **This is the strongest Google-specific tailwind**, but it only
  activates if Duong is willing to write integration code that
  calls Vertex directly — the consumer Ultra plan alone does not
  unlock this.
- **Pragmatic read:** Vertex is a sensible substrate for one-off
  research agents or batch enrichment runs (where prompt caching
  + Gemini Flash + 1M context dominate Claude on cost), but
  replacing the Strawberry harness with ADK is a 6-12 week project
  that should only happen if the Claude harness itself becomes
  untenable — which it hasn't.

---

## 5. Recommendation (ranked, opinion)

Ranked by the three axes the question asked for — cost, capacity
gain, integration cost, long-term strategic fit. All recommendations
are advisory; numbers are best-effort and tagged with confidence.

### Tier 1 — Do these first, before spending more

1. **Measure which Claude cap trips first.** Watch `/status` for a
   week. Opus-first → more Claude seats don't help. Overall-first →
   Team Premium promotion is the cheapest fix. Confidence: high.
2. **Audit prompt-caching coverage in the Strawberry harness.** The
   `_shared/` include bodies, agent `profile.md`, and large system
   prompts should be inside `cache_control: ephemeral` blocks. A
   90% discount on cached input tokens is a free capacity multiplier
   before paying any provider. If this isn't already on, it is the
   highest-leverage change available.
   [platform.claude.com prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
   Confidence: high.
3. **Tighten default model tier.** Any agent-def that doesn't
   actually need Opus (most reviewer/normal-lane roles) should be
   `model: sonnet`. If Opus-cap trips first, this alone may
   eliminate the pain without buying anything. Confidence: high.

### Tier 2 — If capacity pressure persists after Tier 1

4. **Promote 1–2 Team seats from Standard to Premium.** Standard is
   1.25× Pro per session; Premium is 6.25×. The per-seat
   multiplicative jump is the cleanest consumer lever Anthropic sells
   without moving to Enterprise. Confirm exact Premium pricing on
   [claude.com/pricing](https://claude.com/pricing) before commit —
   I did **not** verify a current Premium seat price in this research
   pass. Confidence: medium; pricing unverified.
5. **Add Gemini AI Ultra ($249.99/mo) as a side-channel.** Use for:
   1M-context research on the Strawberry codebase (read entire repo
   at once), Deep Research reports, Jules multi-agent batch workflows,
   and Gemini CLI Plan Mode for read-only architectural passes before
   handing off to Claude for writes. **Do not** wire Gemini into the
   `.claude/agents/*.md` tree. Roughly ~$250/mo for demonstrably
   different capability, not just more of the same. Confidence: high
   that this is useful; medium on $/value vs. Tier 2 #4.
6. **Enable Claude API-key overage** on the Max plan for emergency
   Opus bursts. No monthly commit — pay only on overflow.
   [support.claude.com extra-usage article](https://support.claude.com/en/articles/12429409-manage-extra-usage-for-paid-claude-plans)
   Confidence: high.

### Tier 3 — Only if strategic direction changes

7. **Add a second Max 20x seat** on a separate account, bridged via
   a local proxy if needed. Effectively doubles the weekly Opus cap
   at the cost of session isolation (no shared `/status`, two API
   keys, two login surfaces). Confidence: medium — operational
   overhead is real.
8. **Build a Vertex-ADK lane** for batch/research agents. Only if
   a concrete workload (e.g., large-corpus enrichment, long-running
   overnight agents) appears that Claude can't economically host.
   Confidence: low; premature as of April 2026.
9. **Do not** pursue Enterprise (50-seat minimum, post-Nov-2025
   metered pricing removes the all-inclusive appeal).

### Why "just buy more Claude" is often the right answer

- Zero integration cost. Every existing `.claude/agents/*.md`, every
  hook, every skill, every `_shared/` include works on day one.
- Claude Code's agent-definition conventions are still meaningfully
  ahead of AGENTS.md-style single-file systems for multi-role
  hierarchies like Strawberry's.
- Anthropic's prompt-cache discount is well-understood and already
  compatible with the existing codebase.
- The one scenario where Claude-only loses: a workload that needs
  >400k context in a single turn. Claude's 200k (1M for 4-7 tier)
  ceiling vs. Gemini's 1M is a real capability gap — but it's a
  capability gap, not a capacity gap, and a side-channel Gemini
  subscription covers it at $250/mo without touching the harness.

### Final framing

If Duong's goal is **more capacity** for the existing Claude-agents
workflow, the answer is **inside Claude** (prompt caching audit +
Premium seats + API overage). If Duong's goal is **different
capability** (1M context, Deep Research, Jules-style batch agents,
GCP-native integrations), the answer is **Gemini Ultra as a parallel
side-channel** — $250/mo, no integration debt. If Duong's goal is
**a Plan B provider** in case Claude becomes untenable, Codex CLI is
the closer technical peer to Claude Code than Gemini CLI is, despite
worse GCP affinity — worth trialing on ChatGPT Plus (not Pro) before
committing. The right question isn't "which provider" — it's "which
of these three goals am I solving?"

---

## Sources (all fetched 2026-04-21)

### Claude (Anthropic)

- [Claude pricing page](https://claude.com/pricing)
- [Claude Max plan explained — IntuitionLabs](https://intuitionlabs.ai/articles/claude-max-plan-pricing-usage-limits)
- [Claude Code rate limits — truefoundry](https://www.truefoundry.com/blog/claude-code-limits-explained)
- [Manage extra usage for paid plans](https://support.claude.com/en/articles/12429409-manage-extra-usage-for-paid-claude-plans)
- [Claude Team plan help article](https://support.claude.com/en/articles/9266767-what-is-the-team-plan)
- [Claude Enterprise plan help article](https://support.claude.com/en/articles/9797531-what-is-the-enterprise-plan)
- [Anthropic Enterprise repricing — The Register](https://www.theregister.com/2026/04/16/anthropic_ejects_bundled_tokens_enterprise/)
- [Claude Code peak-hours throttle — TechRadar](https://www.techradar.com/ai-platforms-assistants/claude/claude-is-limiting-usage-more-aggressively-during-peak-hours-heres-what-changed)
- [Opus/Sonnet limit independence question — GitHub issue](https://github.com/anthropics/claude-code/issues/12487)
- [Max 20x exhaustion bug — GitHub issue](https://github.com/anthropics/claude-code/issues/41788)
- [Anthropic prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing)

### Google (Gemini / Vertex)

- [Google AI subscriptions](https://gemini.google/subscriptions/)
- [Google AI Pro & Ultra features — 9to5Google](https://9to5google.com/2026/04/11/google-ai-pro-ultra-features/)
- [Gemini pricing costbench](https://costbench.com/software/ai-chatbots/gemini/)
- [Gemini CLI quotas and pricing](https://geminicli.com/docs/resources/quota-and-pricing/)
- [Gemini Code Assist quotas](https://developers.google.com/gemini-code-assist/resources/quotas)
- [Pro/Ultra higher CLI limits — Google blog](https://blog.google/innovation-and-ai/technology/developers-tools/gemini-cli-code-assist-higher-limits/)
- [Ultra CLI quota complaint — GitHub](https://github.com/google-gemini/gemini-cli/issues/12859)
- [Gemini CLI MCP docs](https://geminicli.com/docs/tools/mcp-server/)
- [Gemini CLI + FastMCP — Google Developers blog](https://developers.googleblog.com/gemini-cli-fastmcp-simplifying-mcp-server-development/)
- [Vertex AI Agent Builder](https://cloud.google.com/products/agent-builder)
- [Vertex AI context caching](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview)
- [Vertex AI pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [Gemini pricing 2026 — rahulkolekar](https://rahulkolekar.com/gemini-pricing-in-2026-gemini-api-vs-vertex-ai-tokens-batch-caching-imagen-veo/)
- [Vertex quota management — oneuptime](https://oneuptime.com/blog/post/2026-02-17-how-to-manage-quotas-and-rate-limits-for-gemini-api-requests-in-vertex-ai/view)

### OpenAI

- [ChatGPT Pro plan article](https://help.openai.com/en/articles/9793128-about-chatgpt-pro-plans)
- [ChatGPT API pricing 2026 — IntuitionLabs](https://intuitionlabs.ai/articles/chatgpt-api-pricing-2026-token-costs-limits)
- [Codex CLI MCP](https://developers.openai.com/codex/mcp)
- [Codex Agents SDK guide](https://developers.openai.com/codex/guides/agents-sdk)
- [Codex AGENTS.md + MCP setup — LLMx](https://llmx.tech/blog/openai-codex-setup-agents-md-mcps-skills-definitive-guide/)

### Cursor / comparisons

- [Cursor pricing](https://cursor.com/pricing)
- [Cursor pricing 2026 — DEV](https://dev.to/rahulxsingh/cursor-pricing-in-2026-hobby-pro-pro-ultra-teams-and-enterprise-plans-explained-4b89)
- [Claude Code vs Codex vs Gemini CLI benchmarks — CodeAnt](https://www.codeant.ai/blogs/claude-code-cli-vs-codex-cli-vs-gemini-cli-best-ai-cli-tool-for-developers-in-2025)
- [Claude Code vs Codex vs Gemini — IntuitionLabs](https://intuitionlabs.ai/articles/claude-code-vs-codex-vs-gemini-cli-comparison)
