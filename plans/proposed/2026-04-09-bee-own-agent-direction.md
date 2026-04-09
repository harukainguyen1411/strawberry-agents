---
status: proposed
owner: syndra
created: 2026-04-09
title: Bee Direction — Build Own Agent with Anthropic SDK
---

# Bee Direction — Build Own Agent with Anthropic SDK

> Strategic assessment. Duong has ruled out Gemini (Vietnamese quality gap is a dealbreaker) and the `claude -p` CLI wrapper (no loop control, opaque). The direction is: build a real agent using the Anthropic SDK, with Claude as the LLM backbone and Duong owning everything around it.

## 1. What this actually means

You are building a program — Python or TypeScript — that runs an agent loop:

```
while task_not_done:
    response = anthropic.messages.create(
        model="claude-sonnet-4-20250514",
        system=system_prompt,
        messages=conversation,
        tools=tool_definitions,
    )
    for block in response.content:
        if block.type == "tool_use":
            result = execute_tool(block)
            conversation.append(tool_result)
        elif block.type == "text":
            collect_output(block)
```

That is the entire core. Everything else — tool definitions, memory injection, output formatting, error handling, multi-step research strategies — is your code. The LLM is a function call inside your loop.

**Two SDK options:**

### Anthropic Messages API (Python `anthropic` / TypeScript `@anthropic-ai/sdk`)

Raw access to `messages.create()`. You define tools as JSON schemas, handle `tool_use` blocks, feed `tool_result` blocks back. Full control, minimal abstraction. This is what most production agent systems use.

### Anthropic Agent SDK (`claude-agent-sdk`, Python)

Higher-level wrapper. Provides `Agent` class with tool registration, `@tool` decorators, built-in multi-turn loop, guardrails, handoffs between agents. Still calls the same API underneath. Adds structure but also opinions — tool execution model, agent-to-agent handoffs, tracing. Good for multi-agent orchestration; slightly over-built for a single-purpose document reviewer.

**Recommendation: Start with the raw Messages API.** The agent loop is ~50 lines of code. The Agent SDK adds complexity that is not justified until you need multi-agent routing. You can always migrate later — the tool definitions are the same JSON schema either way.

## 2. Cost reality check

Claude API is paid. Separate from the Max subscription. No overlap.

### Pricing (as of April 2026)

| Model | Input | Output | Context |
|-------|-------|--------|---------|
| Claude Sonnet 4 | $3/M tokens | $15/M tokens | 200k |
| Claude Haiku 3.5 | $0.25/M tokens | $1.25/M tokens | 200k |

### What a typical Bee job costs

A "comment on this document" job involves:
- System prompt + style rules + instructions: ~2k tokens input
- Document content (typical 5-10 page banking/legal doc): ~3-8k tokens input
- Web search results (3-5 searches, summaries injected): ~5-15k tokens input
- Model reasoning + comments output: ~3-8k tokens output
- Multi-turn tool calls (2-4 rounds): multiply above by ~1.5x for accumulated context

**Estimated per-job token usage:**
- Input: 15-40k tokens
- Output: 5-10k tokens

**Per-job cost (Sonnet):** $0.05 - $0.27

**Monthly at 5 jobs/day:** $7.50 - $40.50/month

**Monthly at 2 jobs/day:** $3.00 - $16.20/month

**Monthly at 10 jobs/day:** $15.00 - $81.00/month

### Can costs approach zero?

**Haiku path:** If Haiku 3.5 quality is acceptable for Vietnamese document commenting, costs drop 12x. Same 5 jobs/day = $0.60 - $3.40/month. But Haiku is meaningfully weaker on nuanced Vietnamese analytical writing — the exact thing that killed Gemini.

**Prompt caching:** Anthropic's prompt caching gives 90% discount on cached input tokens. The system prompt + style rules + tool definitions are identical across jobs — these cache. Document content does not (unique per job). Realistically saves 10-20% on total input cost.

**Batches API:** For non-urgent jobs, the Batches API gives 50% discount. Jobs complete within 24 hours, not real-time. Could work for overnight batch processing but not interactive use.

**Bottom line:** At single-user research-companion volume, expect $5-25/month with Sonnet. This is a paid line item. There is no path to zero cost with Claude API at Sonnet quality. The free tier (Haiku-only, 5 RPM, 20k tokens/min) is insufficient for document analysis.

**This must be a conscious decision by Duong.** The tradeoff is: $10-25/month buys full Vietnamese quality + full loop control + cloud deployment + no Windows dependency. That is the price of owning the product.

## 3. Architecture options

### Option A — Firebase Cloud Functions + Anthropic API (recommended)

```
Browser → Firebase Hosting → Firestore queue
                                    ↓
                          Cloud Function (2nd gen, Python)
                                    ↓
                          Anthropic Messages API (agent loop)
                                    ↓
                          Tool calls: web search, citation check
                                    ↓
                          Structured JSON output
                                    ↓
                          comments.py → .docx → Firebase Storage
```

**Pros:**
- Cloud-native. Works 24/7. Sister is never blocked by Duong's PC being off.
- Cloud Functions 2nd gen: up to 60 min timeout, 32GB RAM. Plenty for an agent loop.
- Free tier: 2M invocations/month, 400k GB-seconds. A 60-second Bee job at 1GB = 60 GB-seconds. At 5 jobs/day = 9,000 GB-seconds/month. Well within free tier.
- Python runtime — `anthropic` SDK, `python-docx`, `comments.py` all run natively.
- Firestore listener triggers the function — no polling, no NSSM, no runlock.

**Cons:**
- Requires Blaze plan (pay-as-you-go billing account). Even if actual spend is $0 on Cloud Functions, the billing account must exist. Anthropic API spend is separate.
- Cold starts: first invocation after idle may take 5-10 seconds. Acceptable for document processing.
- Must bundle `comments.py` and dependencies into the function deployment.

### Option B — Windows-local Python process + Anthropic API

```
Browser → Firebase Hosting → Firestore queue
                                    ↓
                          Windows Python service (NSSM)
                                    ↓
                          Anthropic Messages API (agent loop)
                                    ↓
                          comments.py → .docx → Firebase Storage
```

**Pros:**
- No Blaze plan needed. Firestore client library polls the queue.
- Same topology as the old `claude -p` design — familiar.
- Can run heavier local tools (large PDFs, local file access).

**Cons:**
- Windows dependency returns. Sister gets nothing when PC is off.
- NSSM, runlock, service management overhead — the exact infrastructure the pivot was meant to eliminate.
- API key must be stored on the Windows machine.

### Option C — Hybrid (Cloud Function primary + Windows fallback)

Cloud Function handles normal jobs. Windows worker handles overflow or specialized tasks. Routing logic in Firestore (job field `prefer_local: true`).

**Not recommended for v1.** Adds complexity without clear benefit. If Cloud Functions work (and they will for this workload), there is no reason to maintain the Windows path.

### Recommendation: Option A (Cloud Functions)

The entire motivation for "build our own agent" is to escape the Windows single-point-of-failure and own the reasoning loop. Option A delivers both. The Blaze plan is the only friction — but Blaze with budget alerts set to $1 is effectively free with a safety net.

## 4. What survives from old Bee plans

### Survives intact
- **Firebase frontend** (MyApps route or standalone `bee.web.app`) — UI is backend-agnostic.
- **Firebase Auth** (Google sign-in, UID allowlist) — unchanged.
- **Firestore job queue** (`jobs/{jobId}` schema: status, input doc URL, output doc URL, timestamps) — unchanged.
- **Firebase Storage** (docx upload/download) — unchanged.
- **Firestore security rules** — unchanged.
- **`comments.py` OOXML helper** — survives and gets simpler. Now receives structured JSON directly from the agent loop instead of parsing unstructured LLM text.
- **`style-rules.md` personalization concept** — survives. Injected into the system prompt.
- **Vietnamese locale, mobile-responsive design, .docx workflow** — all unchanged.

### Gets replaced
- **`claude -p` invocation** — replaced by `anthropic.messages.create()` in a proper agent loop.
- **Windows NSSM worker** — replaced by Firebase Cloud Function.
- **Runlock mechanism** — not needed. Cloud Functions handle concurrency natively.
- **MCP servers for custom tools** — tools are just Python functions with JSON schema definitions.

### Gets simplified
- **Output parsing.** Old: Claude outputs free text, fragile regex extracts JSON for comments.py. New: Agent loop requests structured JSON via tool_use or explicit JSON output instructions. The model returns `[{quote, comment, source_url}, ...]` directly.
- **Web search.** Old: hope `claude -p`'s opaque WebSearch finds good Vietnamese sources. New: you define a `web_search` tool, call Tavily or Google Custom Search API, control the query, filter results, inject only relevant content.
- **Error handling.** Old: 25-minute timeout, no partial progress. New: each tool call round-trip is independently retryable. Can checkpoint progress in Firestore.

## 5. What is new

### The agent loop
The core innovation. A Python function (~50-100 lines) that:
1. Receives a job from Firestore (document URL, task type, user preferences).
2. Downloads the document, extracts text.
3. Constructs a system prompt with style rules and task instructions.
4. Enters a multi-turn loop with Claude: sends the document, receives tool calls (web search, citation check), executes them, feeds results back.
5. Collects structured output (comment array as JSON).
6. Passes to `comments.py` for OOXML injection.
7. Uploads the annotated .docx to Firebase Storage.
8. Updates job status in Firestore.

### Tool definitions
You define tools as JSON schemas that Claude can call:

- **`web_search(query: str, num_results: int)`** — calls Tavily, Google Custom Search, or a custom Vietnamese news scraper. Returns titles + snippets + URLs.
- **`read_webpage(url: str)`** — fetches and extracts main content from a URL. For deep-diving into search results.
- **`submit_comments(comments: [{quote, comment, source_url}])`** — the "finish" tool. Structured output that feeds directly into `comments.py`.

Claude decides when and how to use these tools. You control what they do.

### Memory injection
System prompt includes:
- `style-rules.md` — the sister's preferences (formality level, citation style, focus areas).
- Past job summaries — "in previous reviews, you noted X about this document type."
- User corrections — if the sister edits a comment, that feedback feeds into future prompts.

This is not RAG. It is simple prompt injection of a curated context window. Start here. RAG is premature optimization.

### Web search integration
Unlike `claude -p` where web search is opaque, you control:
- Which search provider to use (Tavily: $0, 1000 free searches/month; Google Custom Search: $0, 100 queries/day free).
- What queries to construct (can pre-process the document to extract key terms in Vietnamese).
- What results to inject (filter by relevance, recency, source quality).
- Whether to deep-dive (fetch full page content for promising results).

### Structured output
The agent loop can enforce output structure at the tool level. Define a `submit_comments` tool with a strict JSON schema. Claude must call this tool to "finish" — guaranteeing the output is valid JSON that `comments.py` can consume without parsing.

## 6. Recommendation

**Build with the raw Anthropic Messages API (Python), deployed as a Firebase Cloud Function.**

Rationale:

1. **Vietnamese quality is non-negotiable.** Duong ruled out Gemini for exactly this reason. Claude Sonnet is best-in-class for Vietnamese analytical writing. Owning the API call means owning the quality.

2. **$10-25/month is the real cost of ownership.** There is no free path to Claude-quality Vietnamese at API volume. But this buys: 24/7 cloud availability, full loop control, structured output, custom tools, real personalization, and no Windows dependency. That is a genuine product, not a CLI wrapper.

3. **The agent loop is the product.** The LLM is a commodity input. The value is in: how you orchestrate tool calls, how you structure output for `comments.py`, how you inject personalization, how you handle multi-step research. This code is yours, portable, and improvable independent of any LLM provider.

4. **Cloud Functions eliminate the biggest UX problem.** The sister's experience currently degrades to zero when Duong's PC is off. A Cloud Function works always. This alone justifies the architecture change.

5. **Start simple, own the complexity curve.** Raw Messages API + 3 tools + `comments.py` + Cloud Function. That is the v1. No Agent SDK, no multi-agent, no RAG, no fine-tuning. Add complexity only when the sister's usage reveals what is actually needed.

### Cost management strategy
- Set Anthropic API budget alerts at $25/month and $50/month.
- Log per-job token usage to Firestore for monitoring.
- Use prompt caching (system prompt + style rules cached across jobs).
- Consider Haiku for simple tasks (quick summaries) and Sonnet for complex analysis (document review with citations). Router logic is trivial — a field on the job document.
- Batches API for non-urgent batch processing at 50% discount.

## 7. Open questions for Duong

1. **Budget confirmation.** Are you comfortable with $10-25/month for Anthropic API at Sonnet quality? This is the minimum viable cost for the direction you want.
2. **Blaze plan.** Firebase Cloud Functions require the Blaze (pay-as-you-go) plan. Cloud Function compute itself will be free-tier, but a billing account must be attached. Acceptable?
3. **Python or TypeScript?** Python has better ecosystem for document processing (`python-docx`, existing `comments.py`). TypeScript aligns with the existing MyApps codebase. Recommendation: Python for the Cloud Function worker, keep TypeScript for the frontend.
4. **Web search provider.** Tavily (1000 free searches/month, good quality) vs Google Custom Search (100/day free, good Vietnamese coverage) vs both?
5. **Anthropic API key provisioning.** Need to create an Anthropic API account and load initial credits. Separate from the Max subscription.

## 8. Build plan impact

The existing B1-B10 PR sequence from the approved Bee MVP build plan needs revision:

- **B1 (scaffold)** — rewrite for Cloud Function structure instead of Windows worker.
- **B2 (Firestore wiring)** — rewrite for Cloud Function trigger instead of long-poll.
- **B3 (comments.py)** — survives. Input contract simplifies (structured JSON guaranteed).
- **B4 (claude.ts)** — replaced entirely by Python agent loop module using `anthropic` SDK.
- **B5 (worker orchestration)** — replaced by Cloud Function handler + Anthropic agent loop.
- **B6 (NSSM install)** — eliminated. Cloud Functions handle deployment.
- **B7 (security rules)** — survives unchanged.
- **B8 (frontend upload)** — survives unchanged.
- **B9 (frontend status)** — survives unchanged.
- **B10 (smoke test)** — survives, execution environment changes.

A revised detailed build plan should be written once Duong confirms this direction and the open questions above.
