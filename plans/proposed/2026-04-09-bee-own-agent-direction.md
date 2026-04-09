---
status: proposed
owner: syndra
created: 2026-04-09
title: Bee Direction Assessment — Build Our Own AI Agent vs Claude CLI Worker
---

# Bee Direction Assessment — Build Our Own AI Agent

> Strategic assessment. Not a build plan. Evaluates the pivot away from wrapping Claude Code CLI as a local Windows queue worker toward building a purpose-built AI agent for the sister research companion use case.

## 1. What "our own AI agent" could mean

The current Bee design treats Claude Code CLI as a black box: the worker shells out to `claude -p`, passes a system prompt, and hopes for the best. "Building our own agent" means taking control of the reasoning loop itself. The spectrum:

### Option A — Claude API direct (Anthropic Messages API)

Call `claude-3.5-sonnet` or `claude-3.5-haiku` via the Anthropic Messages API. You control the system prompt, tool definitions, multi-turn loop, and tool execution. The agent IS your code — a loop that sends messages, parses tool_use blocks, executes tools (web search, docx manipulation), feeds results back.

**Access:** Requires API credits. Duong's Max subscription does NOT include API access — these are separate billing. Minimum spend depends on usage; Sonnet is ~$3/M input, $15/M output tokens.

### Option B — Claude Agent SDK (Python)

Anthropic's `claude-agent-sdk` wraps the Messages API with an opinionated agent loop: tool registration, multi-step orchestration, guardrails. Still API-billed. Adds structure but the core economics are identical to Option A.

### Option C — Gemini API (Google AI Studio)

Google's Gemini 2.0 Flash or Gemini 2.5 Pro via the free tier. Google AI Studio provides:
- **Free tier:** 15 RPM, 1M TPM for Flash; 5 RPM for Pro. No credit card required.
- **Tool use:** function calling, code execution, Google Search grounding (built-in, free).
- **Vietnamese:** Gemini 2.0 Flash handles Vietnamese well for comprehension and generation. Not as strong as Claude on nuanced analytical writing, but adequate for comment-on-doc and research summaries.

### Option D — Hybrid (Gemini backbone + Claude CLI for hard tasks)

Use Gemini API as the default agent backbone (free, always-available, cloud-deployed). Fall back to local Claude CLI via the existing Windows worker path only for tasks that exceed Gemini's capability (complex multi-source synthesis, nuanced Vietnamese academic writing). The agent decides which backend to use based on task complexity.

### Option E — Current design (Claude CLI local worker, baseline)

`claude -p` on Duong's Windows computer. No API costs. Full Claude capability. But: tied to one physical machine, no control over the reasoning loop, opaque tool usage, hard to add custom tools beyond MCP servers.

## 2. Architecture comparison

### 2.1 Option E — Current design (Claude CLI worker) — BASELINE

```
Browser → Firebase → Firestore queue → Windows worker → claude -p → docx
```

- **Cost:** $0 (Max subscription, already paid).
- **Capability:** Full Claude with web search, file manipulation. Very strong Vietnamese.
- **Complexity:** Medium. NSSM service, runlock, proper-lockfile, OOXML post-processing.
- **Vietnamese quality:** Excellent. Claude is best-in-class for Vietnamese analytical writing.
- **Docx handling:** Claude generates text; external `comments.py` injects OOXML. Two-step.
- **Web search:** Built-in `WebSearch`/`WebFetch` in Claude CLI. Decent but not controllable.
- **Personalization:** System prompt injection of `style-rules.md`. Works but crude — no mid-session adaptation.
- **Deployment:** Tied to Duong's always-on Windows PC. Sister gets nothing if it's off.
- **Control:** Near zero. `claude -p` is a black box. Can't inspect reasoning steps, can't add custom tool logic mid-loop, can't route to different models per step.

**Key limitations that motivate the pivot:**
1. Single point of failure (one Windows box).
2. No reasoning loop control — can't implement multi-step research strategies.
3. Can't add custom tools (VN news scrapers, citation validators) without MCP server overhead.
4. Output is unstructured text that needs fragile post-processing to become structured JSON for `comments.py`.
5. 25-minute timeout is a blunt instrument — no partial progress, no checkpointing.

### 2.2 Option A/B — Claude API / Agent SDK

```
Browser → Firebase → Cloud Function or always-on worker → Claude API loop → docx
```

- **Cost:** $3-15/M tokens (Sonnet). A typical comment-on-doc job with web search might use 20-50k tokens = $0.06-0.75 per job. At 5 jobs/day = $9-112/month. **This is a paid line item and must be escalated to Duong.**
- **Capability:** Same Claude quality. Plus: full control over tool definitions, multi-step loops, structured output (JSON mode for comment pairs), parallel tool calls.
- **Complexity:** Higher initially (build the agent loop), but cleaner long-term (no NSSM, no runlock, no Windows dependency).
- **Vietnamese quality:** Identical to CLI — same models.
- **Docx handling:** Can request structured JSON output (`{quote, comment, source_url}[]`) directly via tool_use, eliminating fragile text parsing.
- **Web search:** You define the tools. Can wire Tavily, custom VN scrapers, Google Search API as first-class tools with structured input/output.
- **Personalization:** Full control. Can implement RAG over past interactions, dynamic rule selection, multi-turn refinement within a job.
- **Deployment:** Runs anywhere — Cloud Function, Cloud Run, or even still on the Windows box. Not tied to one machine.
- **Control:** Complete. You own the loop. Can log every step, retry failed tools, implement research strategies (search → evaluate → deep-dive → synthesize).

### 2.3 Option C — Gemini API

```
Browser → Firebase → Cloud Function → Gemini API loop → docx
```

- **Cost:** $0 on free tier. Gemini 2.0 Flash: 15 RPM, 1M TPM, 1500 RPD. Gemini 2.5 Pro: 5 RPM, 250k TPM, 50 RPD. For single-user at ~5 jobs/day, free tier is sufficient.
- **Capability:** Gemini 2.0 Flash is competent but not Claude-tier for complex analytical writing. Gemini 2.5 Pro is closer but has tight free-tier rate limits. Function calling works. Google Search grounding is built-in and free.
- **Complexity:** Similar to Option A (build agent loop), but Google's SDK is less polished for agentic patterns than Anthropic's.
- **Vietnamese quality:** Good for comprehension and generation. Weaker than Claude on nuanced register (formal Vietnamese banking reports). Acceptable for comment-on-doc; may struggle with the depth expected in research-mode reports.
- **Docx handling:** Same as Option A — structured output via function calling, external docx generation.
- **Web search:** Google Search grounding is a major advantage — native, free, high quality, includes Vietnamese sources naturally. No need for Tavily or custom scrapers for general search.
- **Personalization:** Same control as Option A — you own the loop.
- **Deployment:** Cloud-native. Can run in a Firebase Cloud Function (free tier: 2M invocations/month). Zero Windows dependency.
- **Control:** Complete.

**Key advantage:** completely free, cloud-native, no Windows dependency, built-in Google Search.
**Key weakness:** Vietnamese analytical writing quality is a step below Claude.

### 2.4 Option D — Hybrid (Gemini default + Claude CLI fallback)

```
Browser → Firebase → Cloud Function → Gemini API loop → docx
                                    ↘ (complex tasks) → Firestore queue → Windows worker → claude -p
```

- **Cost:** $0 for Gemini path. $0 for Claude CLI fallback (Max subscription).
- **Capability:** Best of both — Gemini's free cloud availability + Claude's analytical depth when needed.
- **Complexity:** Highest. Two code paths, routing logic, fallback detection. The Gemini path is fully cloud; the Claude path requires the Windows worker infrastructure from Option E.
- **Vietnamese quality:** Gemini for routine, Claude for complex. Best achievable quality at zero cost.
- **Deployment:** Gemini path is cloud-native (works when Windows is off). Claude path still requires the Windows box.

## 3. Trade-off matrix

| Dimension | E (CLI baseline) | A/B (Claude API) | C (Gemini) | D (Hybrid) |
|---|---|---|---|---|
| **Monthly cost** | $0 | $9-112+ | $0 | $0 |
| **Vietnamese writing** | Excellent | Excellent | Good | Excellent (routed) |
| **Docx handling** | Fragile parse | Structured JSON | Structured JSON | Structured JSON |
| **Web search** | Decent, opaque | Controllable | Excellent (free) | Excellent |
| **Personalization** | Crude (prompt inject) | Full control | Full control | Full control |
| **Deployment** | Windows-tied | Anywhere | Cloud-native | Cloud + Windows |
| **Uptime** | ISP/power dependent | 99.9%+ | 99.9%+ | Graceful degrade |
| **Loop control** | None | Complete | Complete | Complete |
| **Build complexity** | Medium | High | High | Highest |
| **Custom tools** | MCP only | First-class | First-class | First-class |
| **Escalation needed** | No | YES (paid) | No | No |

## 4. Recommendation

**Option C (Gemini API) as primary, with Option D (hybrid) as the planned evolution path.**

Reasoning:

1. **Zero cost is a hard constraint.** Duong's rule: Google + Claude free default, escalate any paid line item. Claude API (Option A/B) introduces real monthly spend that scales with usage. Gemini free tier covers single-user volume comfortably.

2. **Cloud-native solves the biggest UX problem.** The sister's experience degrades to zero when the Windows box is off. A Cloud Function that calls Gemini works 24/7. This is the single biggest improvement over the current design.

3. **Vietnamese quality is good enough for v1.** Gemini 2.0 Flash handles Vietnamese comment-on-doc well. The sister's primary use case (legal/banking document review with inline comments) needs competent Vietnamese and good web search — Gemini delivers both. Google Search grounding for Vietnamese sources is actually superior to Claude's WebSearch for this domain.

4. **Control unlocks the real product.** Building the agent loop (regardless of LLM backend) lets you implement structured output for `comments.py`, multi-step research strategies, custom VN news scrapers as tools, proper citation tracking, and real personalization. This is where "building our own agent" pays off.

5. **Hybrid is the natural evolution.** Once the Gemini agent loop works, adding a Claude CLI fallback for complex research tasks is incremental — the routing logic is a thin layer on top. The Windows worker infrastructure from the current plan can be preserved for this path. Ship Gemini-only first; add Claude fallback if the sister hits quality ceilings.

**The strategic insight:** the value of "building our own agent" is not about which LLM you call — it is about owning the reasoning loop, tool orchestration, and output structure. That investment is LLM-agnostic and survives any backend swap.

## 5. What survives from the current plan

### Survives intact
- **Firebase frontend** (`bee.web.app` or MyApps route) — UI is backend-agnostic.
- **Firebase Auth** (Google sign-in, UID allowlist) — unchanged.
- **Firestore job queue** (`jobs/{jobId}` schema) — unchanged. Worker location changes but the queue contract doesn't.
- **Firebase Storage** (docx upload/download) — unchanged.
- **Firestore security rules** — unchanged.
- **`comments.py` OOXML helper** — unchanged, but now receives structured JSON directly instead of parsing LLM text output.
- **`style-rules.md` personalization concept** — unchanged, injected into whatever LLM's system prompt.
- **Vietnamese locale, mobile-responsive, .docx workflow** — all unchanged.

### Gets replaced
- **Windows NSSM worker as the sole compute path.** Replaced by a Firebase Cloud Function (or lightweight Cloud Run service) that calls Gemini API. The Windows worker becomes optional (hybrid fallback path, not primary).
- **`claude -p` invocation wrapper** (`claude.ts`). Replaced by a Gemini API client with a proper agent loop (tool registration, multi-turn orchestration, structured output).
- **Runlock (`architecture/claude-runlock.md`)** — not needed for the Gemini path. Only relevant if hybrid fallback is implemented.
- **NSSM install scripts, Windows-specific infrastructure.** Deferred to hybrid phase.
- **MCP server dependency for custom tools.** Gemini function calling replaces MCP — tools are just functions in your code.

### Gets simplified
- **`comments.py` integration.** Currently: Claude outputs unstructured text -> fragile parsing -> JSON -> `comments.py`. New: Gemini outputs structured JSON via function calling -> `comments.py` directly. Eliminates the fragile parsing layer.
- **Web search.** Currently: hope Claude's WebSearch finds Vietnamese sources. New: Google Search grounding (built-in, free, strong Vietnamese coverage) + optional custom VN news tool functions.
- **Deployment.** Currently: Windows box must be on, ISP must work, NSSM must be healthy. New: Cloud Function, always available, auto-scaling to zero, free tier covers usage.

### Build plan impact
- **B1 (scaffold), B6 (NSSM install)** — deferred to hybrid phase.
- **B2 (Firestore wiring)** — rewritten for Cloud Function context instead of Node long-poll worker.
- **B3 (comments.py)** — survives, input contract simplifies (structured JSON guaranteed).
- **B4 (claude.ts)** — replaced entirely by Gemini agent loop module.
- **B5 (worker orchestration)** — rewritten as Cloud Function handler instead of NSSM service loop.
- **B7 (security rules), B8 (frontend upload), B9 (frontend status)** — survive unchanged.
- **B10 (smoke test)** — scope unchanged, execution environment changes.

## 6. Open questions for Duong

1. **Gemini API key provisioning.** Google AI Studio free tier requires an API key (not a paid account). Duong likely already has one from the Discord bot Gemini migration. Confirm availability.
2. **Firebase Cloud Functions vs Cloud Run.** Cloud Functions (2nd gen) on the free Blaze plan: 2M invocations/month free, 400k GB-seconds free. A Bee job might run 30-60 seconds — at 5 jobs/day this is ~9000 GB-seconds/month, well within free tier. But Blaze plan requires a billing account (even if spend is $0). Is Duong comfortable enabling Blaze? Alternative: run the Gemini agent loop on the Windows box (same topology as current plan but calling Gemini API instead of `claude -p` — simpler but re-introduces the Windows dependency).
3. **Quality bar.** Has Duong tested Gemini on Vietnamese banking document review? A quick test with Gemini 2.0 Flash on a sample prompt + docx content would validate whether the Vietnamese quality meets the sister's expectations before committing to this direction.
4. **Hybrid timeline.** If Gemini-only ships first, when (if ever) should the Claude CLI fallback be added? Only if the sister reports quality issues? Or proactively?

## 7. Suggested next step

If Duong approves this direction: write a detailed build plan (replacing the current B1-B10 sequence) for the Gemini-first agent architecture. The frontend PRs (B7-B9) carry over nearly unchanged. The worker PRs get rewritten around a Gemini agent loop in a Cloud Function (or Windows-hosted Node process if Blaze is not desired).
