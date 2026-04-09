---
status: proposed
owner: syndra
created: 2026-04-09
title: Bee Direction Assessment — Fully Open-Source AI Agent Stack
---

# Bee Direction Assessment — Fully Open-Source AI Agent Stack

> Strategic assessment. Evaluates building a fully independent AI agent using open-source models — no Claude API, no Gemini API, no proprietary LLM. Duong wants to own the entire stack. Use case unchanged: Vietnamese-language research companion for his sister (upload .docx + Vietnamese prompt, get back .docx with inline comments citing sources).

## 1. Open-source model landscape for Vietnamese

The use case demands three capabilities simultaneously: Vietnamese language quality (comprehension + generation in formal/banking register), instruction following (structured JSON output for comments.py), and tool use / function calling (web search integration). Here is the honest landscape as of early 2026.

### Qwen 2.5 (72B, 32B, 14B, 7B) — STRONGEST CANDIDATE

Alibaba's Qwen family is the standout for Asian languages. Qwen 2.5 72B was trained on multilingual data with heavy CJK and Southeast Asian representation. Vietnamese is not a first-class training language like Chinese, but Qwen consistently outperforms other open models on Vietnamese benchmarks. The 72B variant approaches GPT-4-class on Vietnamese comprehension. The 32B is the practical sweet spot — strong Vietnamese, fits on a single A100/L4 GPU with quantization.

- **Vietnamese quality:** Best-in-class among open models. Formal register is competent. Banking/legal terminology handling is acceptable but noticeably below Claude.
- **Instruction following:** Strong. Supports structured output and function calling natively via Qwen's chat template.
- **Tool use:** Qwen 2.5 has native tool/function calling support. Works with standard agent frameworks.
- **Quantization:** GGUF available. 32B Q4 runs in ~20GB VRAM. 72B Q4 needs ~40GB.

### LLaMA 3.3 (70B) and LLaMA 3.1 (8B, 70B, 405B)

Meta's LLaMA 3.x is the most broadly supported open model. Vietnamese capability exists but is weaker than Qwen — LLaMA's training data skews heavily English/European. The 70B handles Vietnamese reasonably for comprehension but generation quality (especially formal Vietnamese prose) is noticeably rougher than Qwen 72B.

- **Vietnamese quality:** Adequate for comprehension. Generation is serviceable but reads as "translated" — lacks natural Vietnamese flow in formal registers.
- **Instruction following:** Excellent. Best ecosystem support (every framework, every quantization format).
- **Tool use:** Native function calling in LLaMA 3.1+.
- **Practical note:** If you want maximum community support and tooling compatibility, LLaMA is the safe choice. If you want the best Vietnamese output, Qwen wins.

### Mistral Large (123B) and Mistral Nemo (12B)

Mistral models are strong on European languages and code. Vietnamese is a secondary language — performance is below both Qwen and LLaMA 3.x 70B on Vietnamese tasks. Mistral Nemo 12B is impressively efficient but Vietnamese quality is not competitive for this use case.

- **Vietnamese quality:** Below Qwen and LLaMA for this domain. Not recommended as primary.
- **Tool use:** Good function calling support in Mistral Large.

### Gemma 2 (27B, 9B, 2B)

Google's Gemma 2 is efficient and well-suited for on-device deployment. Vietnamese support exists (Google trains on multilingual data) but the 27B ceiling limits its analytical depth compared to 70B+ models. Gemma 2 27B is competitive with LLaMA 3.1 8B on Vietnamese but far below the 70B class.

- **Vietnamese quality:** Acceptable for simple tasks. Insufficient for formal banking document analysis.
- **Best use:** Could serve as a lightweight classifier or router, not the primary reasoning model.

### Phi-4 (14B)

Microsoft's Phi-4 is impressive for its size on English reasoning benchmarks. Vietnamese support is minimal — Phi models are heavily English-centric. Not viable for this use case.

### Summary ranking for Vietnamese banking document analysis

| Model | Vietnamese Quality | Tool Use | Practical Size | Verdict |
|---|---|---|---|---|
| Qwen 2.5 72B | Best open-source | Native | 40GB Q4 | Top pick if GPU budget allows |
| Qwen 2.5 32B | Very good | Native | 20GB Q4 | Best cost/quality ratio |
| LLaMA 3.3 70B | Good | Native | 38GB Q4 | Safe fallback, huge ecosystem |
| Mistral Large 123B | Adequate | Good | 65GB Q4 | Overkill, Vietnamese not strong enough |
| Gemma 2 27B | Weak for domain | Basic | 16GB Q4 | Not recommended as primary |
| Phi-4 14B | Poor | Limited | 8GB Q4 | Not viable |

**Recommendation: Qwen 2.5 32B** as the primary model. Best Vietnamese quality at a practical VRAM footprint. Fall back to Qwen 72B if quality is insufficient.

## 2. Local vs hosted — infrastructure options

### Local development: Ollama

Ollama is the right tool for local dev and testing. Run `ollama pull qwen2.5:32b` and you have a local inference server with an OpenAI-compatible API. Duong's Windows machine needs a GPU with at least 24GB VRAM for 32B Q4 (RTX 3090/4090). If he only has 8-16GB VRAM, he is limited to 7B-14B models locally, which are not sufficient quality for this use case.

**Local is for development only.** For production (sister using it anytime), cloud hosting is necessary unless Duong's machine is always-on with sufficient GPU.

### GCP hosting options

#### Option A — GCE with GPU (cheapest for always-on)

A single GCE VM with an NVIDIA L4 GPU (24GB VRAM, enough for Qwen 2.5 32B Q4):
- **Cost:** L4 GPU on GCE = ~$0.24/hr spot, ~$0.70/hr on-demand. **Always-on: ~$500/month on-demand, ~$175/month spot.** This is not free or near-free.
- **Setup:** Ubuntu VM, install vLLM or text-generation-inference (TGI), load model, expose API behind a Cloud Run proxy or direct.
- **Pros:** Full control, persistent model in memory, fast inference (no cold start).
- **Cons:** Expensive for a single-user app. Spot instances can be preempted.

#### Option B — Cloud Run with GPU (pay-per-request, sort of)

Cloud Run now supports GPU instances (L4). You can set min-instances=0 for scale-to-zero.
- **Cost:** Same GPU rate while running (~$0.70/hr), but only billed while processing requests. Cold start: 2-5 minutes to load a 32B model from disk. For a single user doing 5 jobs/day, maybe 1-2 hours of GPU time = ~$1-1.40/day = **~$30-42/month.**
- **Pros:** Pay only for usage. No VM management.
- **Cons:** Cold starts are brutal (minutes). The sister submits a job and waits 5+ minutes for the first response of the day. Subsequent requests within the keepalive window are fast.

#### Option C — Vertex AI Model Garden

Vertex AI hosts open models (LLaMA, Gemma) with managed endpoints. Qwen availability on Vertex varies. If available:
- **Cost:** Similar to GCE GPU pricing but with managed infrastructure markup.
- **Pros:** No infrastructure management.
- **Cons:** Less model choice, still expensive, vendor lock-in to Google's serving stack.

#### Option D — External GPU cloud (RunPod, Vast.ai, Lambda)

- **RunPod serverless:** Pay per second of GPU time. L4 at ~$0.20/hr. Supports vLLM. Cold starts exist but are managed.
- **Vast.ai:** Community GPU marketplace. Cheapest option (~$0.10-0.20/hr for L4-class). Less reliable.
- **Lambda Labs:** On-demand A10G at ~$0.60/hr.
- **Cost for single user:** Similar to Cloud Run — ~$20-40/month depending on usage patterns.

#### Is there a free path?

**No.** There is no free GPU inference tier on any major cloud provider that can run a 32B model. Google Cloud free tier has no GPU. The smallest viable GPU (T4, 16GB) can run Qwen 14B but quality drops significantly. Even T4 spot on GCE is ~$0.12/hr = ~$87/month always-on.

The only "free" paths are:
1. Run on Duong's own GPU hardware (RTX 3090/4090) — but re-introduces the always-on Windows dependency.
2. Use a smaller model (7B-14B) that fits on free-tier CPU instances — but Vietnamese quality becomes unacceptable for banking document analysis.
3. Use Hugging Face Inference API free tier — severely rate-limited (a few requests per hour), not viable for real usage.

**Bottom line: open-source inference costs $20-50/month minimum for usable quality on this task.** This must be escalated to Duong as a paid line item. Compare with Gemini API free tier ($0) or Claude API ($9-112/month).

## 3. Agent framework — build vs adopt

### Build from scratch

The "agent loop" for Bee is simple: receive job -> load document -> construct prompt -> call LLM with tools -> parse tool calls -> execute tools (web search) -> collect results -> call LLM again -> repeat until done -> format output as structured JSON -> pass to comments.py.

This is 200-400 lines of Python. The loop is:
```
while not done:
    response = llm.chat(messages, tools=tool_definitions)
    for tool_call in response.tool_calls:
        result = execute_tool(tool_call)
        messages.append(tool_result(result))
    if response.stop_reason == "end_turn":
        done = True
```

For a single-developer, single-use-case agent, **building from scratch is the right call.** The LLM client (Ollama's OpenAI-compatible API or vLLM) handles the inference. You just need the orchestration loop.

### Framework options if you want one

- **LangChain:** Massive ecosystem, but heavy abstraction overhead. Adds complexity without proportional value for a focused single-agent use case. Not recommended.
- **LlamaIndex:** Best for RAG-heavy applications. If document understanding becomes complex (multi-document cross-referencing), LlamaIndex's document ingestion pipeline is valuable. Overkill for v1.
- **AutoGen / CrewAI:** Multi-agent orchestration frameworks. Complete overkill for a single-agent use case.
- **Haystack (deepset):** Clean pipeline-based architecture. Good for search + LLM workflows. Worth considering if the web search integration becomes complex.

**Recommendation: build from scratch for v1.** The agent loop is trivial. Use the OpenAI-compatible client library (which works with Ollama, vLLM, and any OpenAI-compatible server). If complexity grows, adopt LlamaIndex for document processing or Haystack for search pipelines. Do not start with LangChain.

## 4. Web search — free options

Even with a free LLM, web search is a dependency. The agent needs to find Vietnamese-language sources to cite.

### Free or near-free options

| Option | Cost | Quality | Vietnamese Coverage | Notes |
|---|---|---|---|---|
| **SearXNG (self-hosted)** | $0 (self-host) | Good | Good (aggregates Google, Bing, etc.) | Best free option. Meta-search engine you host yourself. Aggregates results from multiple engines without API keys. Deploy on same GCE VM as the model. |
| **DuckDuckGo Instant Answer API** | $0 | Limited | Weak | Only instant answers, not full web search. Insufficient. |
| **Google Custom Search JSON API** | Free: 100 queries/day | Excellent | Excellent | 100/day is tight for research jobs (each job might need 5-10 searches = 10-20 jobs/day max). Paid: $5/1000 queries. |
| **Brave Search API** | Free: 2000 queries/month | Good | Adequate | ~66/day. Decent free tier. Vietnamese coverage is weaker than Google. |
| **Serper** | Free: 2500 queries on signup | Good | Good (Google results) | One-time free credits, then paid. Not sustainable. |
| **Tavily** | Free: 1000 queries/month | Excellent | Good | ~33/day. Best quality for AI agent use but limited free tier. |
| **Direct scraping** | $0 | Varies | Full | Use `httpx` + `BeautifulSoup` to scrape Google search results directly. Fragile (Google blocks scrapers) but free. |

**Recommendation: SearXNG self-hosted** as primary (unlimited, free, good Vietnamese coverage). Supplement with Brave Search API free tier for backup. If Duong enables GCE for the model server, SearXNG runs on the same VM at zero marginal cost.

## 5. Vietnamese quality reality check

This is the section that matters most. Honest assessment.

### What Claude/GPT do well on Vietnamese banking documents

- Natural, fluent formal Vietnamese that reads like it was written by a Vietnamese banking professional.
- Correct use of specialized terminology (e.g., "lai suat co ban", "ty le an toan von", "no xau nhom 3-5") without awkward phrasing.
- Nuanced analytical comments that demonstrate understanding of regulatory context (NHNN circulars, Basel III adaptation in Vietnam).
- Consistent register — does not randomly switch between formal and colloquial Vietnamese.
- Accurate citation integration — weaves source references naturally into Vietnamese prose.

### What open-source models actually do

- **Qwen 2.5 72B:** Competent Vietnamese. Formal register is mostly correct. Occasionally produces Chinese-influenced phrasing or uses less natural Vietnamese constructions. Banking terminology is handled but sometimes with explanatory circumlocutions rather than direct professional usage. **Gap vs Claude: noticeable but workable. Maybe 75-80% of Claude's Vietnamese quality.**
- **Qwen 2.5 32B:** Similar to 72B but with more frequent register breaks. May occasionally generate a sentence that sounds translated. Banking terminology coverage is slightly thinner. **Gap vs Claude: significant. Maybe 65-70%.**
- **LLaMA 3.3 70B:** Vietnamese generation reads like competent but non-native writing. The "translated from English" feel is persistent in formal documents. Banking terminology is often rendered in English or with awkward Vietnamese equivalents. **Gap vs Claude: large. Maybe 55-60%.**
- **14B and smaller models:** Not viable for formal Vietnamese banking analysis. Output quality drops sharply.

### The honest verdict

Open-source models cannot match Claude or GPT-4 on Vietnamese banking document analysis today. The gap is real and meaningful:

1. **For simple comment-on-doc** (highlight a clause, add a short analytical comment): Qwen 32B-72B is adequate. The comments are short enough that quality issues are manageable.
2. **For research-mode reports** (multi-page Vietnamese analysis with citations): The quality gap becomes painful. The sister will notice.
3. **For casual Vietnamese** (non-domain-specific): Open models are fine.

The question is whether "adequate" is enough for the sister's actual workflow. If she is comparing against Claude-quality output she has already seen, she will perceive the downgrade.

## 6. Recommendation

### Is this direction viable?

**Partially.** The technical stack works — you can build a functional open-source agent that does the job. The problems are economic and qualitative:

1. **It is not free.** GPU inference costs $20-50/month minimum for usable quality (32B+ model). This negates the primary advantage over Gemini API (which is genuinely free) and is comparable to Claude API costs for this usage volume.

2. **Vietnamese quality is measurably worse.** Qwen 32B is the best open option and it is still noticeably below Claude on formal Vietnamese. The sister will perceive this.

3. **Complexity is highest.** You are now responsible for model serving infrastructure, GPU provisioning, model updates, quantization tuning, and search infrastructure — on top of the agent logic and frontend. Single-developer overhead is substantial.

4. **The "own the stack" benefit is real but premature.** Owning the full stack matters when you are at scale, when you need custom fine-tuning, or when you have privacy constraints. For a single-user family tool, the operational burden outweighs the sovereignty benefit.

### If Duong proceeds anyway — recommended stack

```
Frontend:  Firebase Hosting (existing MyApps route)
Auth:      Firebase Auth (Google sign-in, unchanged)
Queue:     Firestore (job documents, unchanged)
Storage:   Firebase Storage (docx upload/download, unchanged)

Model:     Qwen 2.5 32B-Q4 via vLLM on GCE (L4 GPU, spot instance)
           OR Qwen 2.5 32B on RunPod serverless
Agent:     Custom Python loop (no framework), OpenAI-compatible client
Search:    SearXNG self-hosted (same VM) + Brave Search API free tier
Docx:      comments.py (unchanged, receives structured JSON)

Worker:    Cloud Run service that receives Firestore trigger,
           calls vLLM endpoint + SearXNG, returns structured comments
```

**Estimated monthly cost: $25-50** (GPU instance, spot pricing, usage-dependent).

### Alternative recommendation

If the goal is independence from proprietary APIs specifically (rather than open-source ideology), consider this middle ground:

- **Gemini API free tier** for v1 (ships fast, zero cost, good Vietnamese, the sister gets a working tool immediately).
- **Parallel experimentation** with Qwen 32B locally on Duong's GPU to evaluate Vietnamese quality firsthand.
- **Migration to open-source** only if: (a) Duong confirms the quality is acceptable after hands-on testing, and (b) the cost of GPU hosting is acceptable as an ongoing expense.

This gives the sister a working tool NOW while Duong validates the open-source path on his own timeline. The agent loop code is identical — only the LLM backend URL changes.

## 7. What survives from Bee plans

### Survives intact
- **Firebase frontend** (bee.web.app or MyApps route) — UI is backend-agnostic.
- **Firebase Auth** (Google sign-in, UID allowlist) — unchanged.
- **Firestore job queue** (`jobs/{jobId}` schema) — unchanged. Worker location changes but queue contract doesn't.
- **Firebase Storage** (docx upload/download) — unchanged.
- **Firestore security rules** — unchanged.
- **`comments.py` OOXML helper** — unchanged. Now receives structured JSON from whatever LLM backend.
- **`style-rules.md` personalization concept** — unchanged, injected into whatever model's system prompt.
- **Vietnamese locale, mobile-responsive, .docx workflow** — all unchanged.
- **B7 (security rules), B8 (frontend upload), B9 (frontend status)** — survive unchanged.
- **B3 (comments.py)** — survives, input contract simplifies.

### Gets replaced
- **Windows NSSM worker** — replaced by Cloud Run or GCE-hosted worker calling self-hosted LLM.
- **`claude -p` invocation** — replaced by OpenAI-compatible API call to vLLM/Ollama endpoint.
- **Runlock infrastructure** — not needed for cloud-hosted model endpoint.
- **Claude CLI dependency entirely** — no proprietary LLM in the loop.

### Gets added (new infrastructure)
- **GPU VM or serverless GPU** — model serving infrastructure (vLLM + Qwen).
- **SearXNG instance** — self-hosted search aggregator.
- **Model management** — downloading, quantizing, updating open models.
- **Monitoring** — GPU utilization, model health, inference latency tracking.

## 8. Open questions for Duong

1. **GPU budget.** Is $25-50/month acceptable for GPU inference? If not, the open-source path is not viable at acceptable quality — Gemini free tier is the only $0 option.
2. **Quality test.** Has Duong tested Qwen 2.5 on Vietnamese banking documents? Before committing to this direction, run a side-by-side comparison: same prompt + same document through Claude, Gemini Flash, and Qwen 32B. Compare output quality. This takes 30 minutes and prevents a multi-week build on a foundation that does not meet the sister's expectations.
3. **Local GPU.** What GPU does Duong's Windows machine have? If RTX 3090/4090 (24GB VRAM), local serving is viable for development and potentially production (if always-on is acceptable). If less than 24GB, local is dev-only with smaller models.
4. **Timeline priority.** Does Duong want the sister to have a working tool soon (favors Gemini free tier now, open-source later) or is he willing to spend weeks on infrastructure before she gets anything (favors open-source first)?
5. **Fine-tuning interest.** One genuine advantage of open-source: you can fine-tune Qwen on Vietnamese banking documents to close the quality gap. Is Duong interested in this path? It adds significant complexity but could eventually exceed proprietary model quality for this narrow domain.
