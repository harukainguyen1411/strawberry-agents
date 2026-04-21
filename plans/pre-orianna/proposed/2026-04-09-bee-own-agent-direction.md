---
status: proposed
owner: syndra
created: 2026-04-09
title: Bee — Build Your Own Agent Framework Around claude -p
---

# Bee — Build Your Own Agent Framework Around `claude -p`

> Learning project. Duong builds a custom Python orchestrator that wraps `claude -p` CLI as the intelligence layer. He owns everything except the model itself: the agent loop, tool definitions, memory injection, prompt assembly, structured output parsing. The sister's research companion is the concrete project that makes this real, not abstract.

## 1. What "building your own agent" means here

An AI agent is a loop. The model does not "do" anything — it receives text and returns text. Everything else is orchestration code that you write:

```
while not done:
    prompt = assemble_prompt(system, memory, history, tool_results)
    response = call_claude(prompt)          # claude -p "{prompt}"
    if response contains tool_calls:
        for call in tool_calls:
            result = execute_tool(call)
            history.append(tool_result)
    else:
        done = True
        final_answer = response
```

**What Claude does:** Reads the prompt, reasons, decides whether to call a tool or produce a final answer, returns structured text.

**What you build:**
- **Prompt assembly** — combining system instructions, memory files, conversation history, and tool results into the string that `claude -p` receives.
- **Tool definitions** — describing available tools in the system prompt so Claude knows what it can call. Parsing Claude's output to detect tool calls. Executing the tool. Feeding results back.
- **Memory management** — deciding what context to inject (style rules, past interactions, domain knowledge) and how to keep it within token limits.
- **Structured output parsing** — getting Claude to return JSON (or another format) and reliably extracting it from the response.
- **The loop itself** — retry logic, error handling, max-iteration guards, logging.

`claude -p` is the execution layer. It takes a prompt string and returns a completion. Zero API keys, zero per-token cost — it runs against Duong's Claude Max 20x subscription. The orchestrator is the learning artifact.

## 2. Learning path — concepts in order

Each concept builds on the previous. Build something small for each one before moving to the next.

### Phase 1: Single-shot prompting (day 1)
- Call `claude -p "your prompt here"` from Python (`subprocess.run`)
- Parse the stdout response
- Understand: prompt in, completion out, nothing magic
- **Build:** A script that takes a question and prints Claude's answer

### Phase 2: System prompts and prompt templates (day 1-2)
- Construct multi-part prompts: system instructions + user message
- Use `claude -p` with `--system-prompt` flag (or embed system prompt in the prompt string)
- Understand: the system prompt shapes behavior, you control it entirely
- **Build:** A script that loads a persona file and answers questions in that persona

### Phase 3: Structured output (day 2-3)
- Ask Claude to return JSON by specifying the schema in the system prompt
- Parse the JSON from the response (handle markdown code fences, partial JSON, etc.)
- Understand: structured output is a prompt engineering problem + a parsing problem
- **Build:** A script that analyzes a text file and returns JSON with specific fields (title, summary, key_points)

### Phase 4: Tool use — the core concept (day 3-5)
- Define tools as JSON schemas in the system prompt ("You have access to these tools...")
- Detect when Claude's response contains a tool call (by parsing structured output)
- Execute the tool (a Python function), format the result, feed it back
- Understand: tool use is not a special API feature — it is structured output + a loop
- **Build:** An agent that can use a `web_search` tool (calls a search API) and a `read_file` tool (reads a local file). Ask it a question that requires searching, watch it call the tool, see the result fed back, watch it answer.

### Phase 5: The agent loop (day 5-7)
- Implement the full while loop: prompt -> response -> tool calls -> execute -> re-prompt -> ... -> final answer
- Add iteration limits (max 10 turns), error handling, logging
- Understand: this is the entire agent pattern. Everything else is refinement.
- **Build:** The Bee research agent v0 — takes a question in Vietnamese, searches the web, synthesizes an answer with citations

### Phase 6: Memory injection (day 7-10)
- Load context files (style rules, user preferences, domain knowledge) into the system prompt
- Implement token budget management — what fits, what gets truncated, what gets summarized
- Understand: memory is just "stuff you put in the prompt." The hard problem is selection and compression.
- **Build:** Add style-rules.md injection to Bee so the sister's preferences shape output tone

### Phase 7: Conversation history and multi-turn (day 10-14)
- Maintain a message history across turns within a single job
- Implement history truncation (sliding window, summarization of old turns)
- Understand: multi-turn is memory management for recent context
- **Build:** Add multi-turn capability to Bee so it can refine its analysis based on follow-up instructions

## 3. Architecture

### The orchestrator (Python)

```
bee/
  orchestrator.py      # The agent loop
  prompt.py            # Prompt assembly (system + memory + history + tools)
  tools.py             # Tool definitions and execution
  parser.py            # Structured output parsing (JSON extraction)
  memory.py            # Memory file loading and token budgeting
  claude.py            # Thin wrapper around subprocess calling claude -p
  config.py            # Model settings, paths, limits

  tools/
    web_search.py      # SearXNG or Brave Search integration
    read_document.py   # .docx text extraction
    write_comments.py  # Calls comments.py to produce annotated .docx

  memory/
    system-prompt.md   # Base system instructions for Bee
    style-rules.md     # Sister's personalization rules
```

### How `claude -p` gets called

```python
import subprocess, json

def call_claude(prompt: str, system: str = None) -> str:
    cmd = ["claude", "-p"]
    if system:
        cmd += ["--system-prompt", system]
    cmd.append(prompt)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return result.stdout
```

The orchestrator never touches the Claude API. It shells out to the CLI. The CLI handles authentication via Max subscription. Cost: zero marginal.

### Tool definitions in the system prompt

Tools are described in natural language + JSON schema within the system prompt:

```
You have access to the following tools. To use a tool, respond with a JSON block:
{"tool": "tool_name", "arguments": {...}}

Available tools:

1. web_search
   Description: Search the web for information.
   Arguments: {"query": "string"}
   Returns: List of search results with titles, URLs, and snippets.

2. read_document
   Description: Read the contents of an uploaded .docx file.
   Arguments: {"file_path": "string"}
   Returns: Extracted text content of the document.

3. write_comments
   Description: Add inline comments to a .docx file.
   Arguments: {"file_path": "string", "comments": [{"paragraph": int, "text": "string", "citation": "string"}]}
   Returns: Path to the annotated document.

When you have enough information to provide a final answer, respond normally without a tool call.
```

The parser looks for `{"tool": ...}` in the response. If found, it executes the tool and loops. If not found, the response is the final answer.

### Memory injection

```python
def assemble_prompt(job, history, tool_results):
    system = load_file("memory/system-prompt.md")
    style = load_file("memory/style-rules.md")

    # Token budget: ~150k available, reserve 50k for response
    budget = 100_000

    parts = [system, f"\n## Style Rules\n{style}"]
    remaining = budget - count_tokens(parts)

    # Add document content (truncate if needed)
    doc_text = extract_docx(job.file_path)
    parts.append(f"\n## Document\n{doc_text[:remaining]}")

    # Add conversation history
    for msg in history:
        parts.append(format_message(msg))

    return "\n".join(parts)
```

## 4. What survives from Bee plans

### Survives intact
- **Firebase frontend** — UI for uploading .docx, viewing status, downloading results. Backend-agnostic.
- **Firebase Auth** — Google sign-in, UID allowlist for the sister.
- **Firestore job queue** — `jobs/{jobId}` documents. The worker polls or listens, processes, updates status.
- **Firebase Storage** — .docx upload and download.
- **comments.py** — OOXML helper that takes structured JSON and produces annotated .docx. Unchanged.
- **style-rules.md personalization** — injected into the system prompt. Unchanged concept.
- **Security rules, frontend upload/status UI** — all survive.

### Gets replaced
- The "which LLM" question is settled: `claude -p`, zero cost, best Vietnamese quality.
- No GPU infrastructure, no vLLM, no model serving. Claude Max handles inference.
- No open-source model evaluation needed.

## 5. What is new — the learning artifact

The orchestrator is the thing Duong builds himself. It is not a library, not a framework — it is ~500 lines of Python that he understands completely because he wrote every line. Specifically:

1. **`claude.py`** — The subprocess wrapper. Teaches: how CLI tools become programmatic interfaces.
2. **`prompt.py`** — Prompt assembly. Teaches: prompt engineering is software engineering (templates, composition, token budgets).
3. **`tools.py`** — Tool definitions and execution. Teaches: the core agent pattern (LLM decides, code executes).
4. **`parser.py`** — Structured output extraction. Teaches: the fragility boundary between natural language and structured data.
5. **`orchestrator.py`** — The loop. Teaches: agents are just loops with LLM calls inside them.
6. **`memory.py`** — Context management. Teaches: the hardest unsolved problem in agent systems (what context to include, what to drop).

After building this, Duong will understand how every agent framework works because they all implement these same six components. The difference is abstraction depth, not concept.

## 6. Suggested v1 scope

**Goal:** A working agent that takes a Vietnamese-language question + optional .docx, searches the web, and returns an answer with citations. Runs locally via `claude -p`. No frontend yet — CLI input, CLI output.

### v1 deliverables
1. `claude.py` — subprocess wrapper with timeout and error handling
2. `prompt.py` — assembles system prompt + style rules + user query + tool results
3. `parser.py` — extracts JSON tool calls from Claude's response, handles edge cases
4. `tools.py` + `tools/web_search.py` — web search via Brave Search free tier (2000 queries/month, no self-hosting needed for v1)
5. `orchestrator.py` — the agent loop (max 5 tool calls per job)
6. A CLI entry point: `python bee.py "Phan tich xu huong lai suat ngan hang Viet Nam 2026"`

### v1 explicitly excludes
- Firebase frontend (Phase 2)
- .docx processing and comments.py integration (Phase 2)
- Firestore job queue (Phase 3)
- Multi-turn conversation (Phase 3)
- Memory persistence across jobs (Phase 3)

### v1 time estimate
- 3-5 focused evenings if building deliberately and learning along the way
- Could be done in one day if rushing, but rushing defeats the purpose

## 7. Gemini Pro as an option

Duong has Gemini Pro via Google One AI Premium. This is available for experimentation and comparison but Claude is the primary execution layer.

Potential uses for Gemini:
- **Side-by-side comparison** — run the same prompt through both `claude -p` and Gemini API to compare output quality on Vietnamese tasks. Educational for understanding model differences.
- **Fallback** — if Claude CLI has downtime or rate limits under Max, Gemini is a backup path. The orchestrator's `claude.py` module can be swapped for a `gemini.py` module with the same interface.
- **Cost experiment** — Gemini API has a free tier. If Duong ever wants to run Bee as a hosted service (not just local CLI), Gemini avoids per-token costs for low volume.

The orchestrator architecture is model-agnostic by design. The `call_claude()` function is the only model-specific code. Swapping it for `call_gemini()` (using the Gemini API) is a 20-line change. This is itself a learning outcome: good agent architecture separates orchestration from inference.

## 8. Open questions

1. **Web search for v1.** Brave Search free tier (2000/month) is simplest. Alternatively, Google Custom Search (100/day free). Which does Duong prefer, or should v1 just start with Brave?
2. **Repo location.** Does the Bee orchestrator live in `apps/bee-worker/` within this repo, or in a separate repo? Separate repo is cleaner for a learning project.
3. **Python version.** Assuming 3.11+ is available. Any constraints?
