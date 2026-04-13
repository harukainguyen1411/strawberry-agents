---
status: implemented
owner: syndra
created: 2026-04-13
title: Bee — Gemini-Powered Intake Assistant
---

# Bee — Gemini-Powered Intake Assistant

> Conversational pre-processing layer that sits between Haruka's file upload and the bee-worker. A Gemini model reads the input, identifies ambiguity, asks clarifying questions in-chat, and synthesizes a structured spec before anything reaches the GitHub Issue queue. Goal: eliminate churn from underspecified requests.

## Current State

- Bee lives at `apps/yourApps/bee`, route `/yourApps/bee` on `apps.darkstrawberry.com`.
- Haruka uploads a `.docx` to Firebase Storage at `bee-temp/<uid>/<timestamp>/input.docx`.
- A GitHub Issue is filed; the GCE bee-worker (e2-micro, 35.222.48.28) polls issues and runs Claude on the request.
- Cloud Functions exist at `apps/functions/` (v2, TypeScript) — currently handles notification dispatch and GitHub issue creation via Octokit.
- No Gemini integration exists today. This is fresh.

## Proposed Flow

```
Haruka                    Portal (Vue)                 Cloud Function              Gemini API
  |                           |                              |                         |
  |-- upload .docx ---------->|                              |                         |
  |   or type request         |                              |                         |
  |                           |-- POST /beeIntakeStart ----->|                         |
  |                           |   {uid, sessionId,           |-- createSession ------->|
  |                           |    fileRef?, textInput?}     |   (system prompt +      |
  |                           |                              |    file/text content)   |
  |                           |<-- {geminiResponse, done} ---|<-- clarifying Qs -------|
  |<-- show bot questions ----|                              |                         |
  |                           |                              |                         |
  |-- answer questions ------>|                              |                         |
  |                           |-- POST /beeIntakeTurn ------>|                         |
  |                           |   {sessionId, userMessage}   |-- continueSession ----->|
  |                           |<-- {geminiResponse, done} ---|<-- more Qs or final ----|
  |                           |                              |                         |
  |   ... repeat until done=true ...                         |                         |
  |                           |                              |                         |
  |-- click "Send to Bee" --->|-- POST /beeIntakeSubmit ---->|                         |
  |                           |   {sessionId}                |                         |
  |                           |                              |-- file GitHub Issue ---->|
  |                           |<-- {issueUrl} ---------------|                         |
```

## 1. Where the Gemini Call Lives

**Recommendation: Firebase Cloud Function (v2, callable).**

The Gemini API key is a secret. Shipping it to the client is not an option. The existing `apps/functions/` already has Octokit and Firestore access, so adding Gemini there keeps the secret server-side and reuses the deployment pipeline.

Three new callable functions:

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `beeIntakeStart` | Create session, send initial input to Gemini | `{fileRef?, textInput?}` | `{sessionId, botMessage, done}` |
| `beeIntakeTurn` | Continue conversation | `{sessionId, userMessage}` | `{botMessage, done}` |
| `beeIntakeSubmit` | Finalize and file GitHub Issue | `{sessionId}` | `{issueUrl}` |

API key storage: Firebase Functions environment variable (`GEMINI_API_KEY`), set via `firebase functions:secrets:set GEMINI_API_KEY`. Never committed to source.

Dependency: `@google/generative-ai` npm package added to `apps/functions/`.

## 2. Gemini Model Selection

**Default: `gemini-2.5-flash`.**

Rationale:
- Latency: sub-second for short conversational turns. Intake questions are short — rarely over 200 tokens output per turn.
- Cost: roughly 10x cheaper than Pro per token. At estimated 5-10k input tokens per session (file content + conversation), cost per intake is negligible.
- Quality: Flash handles structured Q&A, rubric-based gap analysis, and JSON output reliably. The task is classification + structured extraction, not creative reasoning.
- Fallback: if Flash produces low-quality output (detected by malformed JSON or user complaint), the function can retry once with `gemini-2.5-pro`. This is a code-level fallback, not user-facing.

No fine-tuning. Prompt engineering only.

## 3. Conversation State Management

**Firestore collection: `bee-intake-sessions/{sessionId}`**

```
bee-intake-sessions/
  {sessionId}/                    # auto-generated ID
    uid: string                   # Haruka's Firebase Auth UID
    status: "active" | "complete" | "abandoned" | "error"
    fileRef: string | null        # Storage path to uploaded file
    originalTextInput: string | null
    finalSpec: object | null      # The structured JSON output from Gemini
    turnCount: number
    totalInputTokens: number
    totalOutputTokens: number
    createdAt: Timestamp
    updatedAt: Timestamp
    messages/                     # subcollection
      {messageId}/
        role: "user" | "model"
        content: string
        timestamp: Timestamp
        tokenCount: number        # for budget tracking
```

**Cleanup policy:**
- Sessions with status `complete`: retained 90 days, then TTL-deleted (Firestore TTL policy on `updatedAt + 90d`).
- Sessions with status `abandoned` (no turn in 24h): TTL-deleted after 7 days.
- Sessions with status `error`: retained 30 days for debugging.

The full conversation history is reconstructed from the `messages` subcollection and sent to Gemini on each turn (stateless from Gemini's perspective — the function manages context). This avoids depending on Gemini's server-side session state.

## 4. File Reading

**Recommendation: Option A — server-side text extraction via `mammoth`.**

Rationale against Option B (Gemini File API):
- Gemini's File API supports docx, but requires a separate upload call to `generativelanguage.googleapis.com`, file processing delay, and cleanup. It adds a second API surface to manage.
- Most of Haruka's docx files are text-heavy research requests. `mammoth` extracts clean HTML/text from docx in milliseconds, and the extracted text is what we actually want Gemini to reason about.
- Text extraction also lets us enforce the token budget precisely — we know exactly how many tokens the file contributes.

Implementation:
1. `beeIntakeStart` receives `fileRef` (Storage path).
2. Function downloads the file from Firebase Storage to a temp buffer (Cloud Functions have `/tmp` with 512MB).
3. `mammoth.extractRawText(buffer)` produces plain text.
4. Text is truncated to 30k characters (approximately 8k tokens) if it exceeds that limit — with a note appended: "[Document truncated. Full document available to bee-worker.]"
5. Extracted text is included in the first Gemini prompt as the "original request content."

Dependency: `mammoth` npm package added to `apps/functions/`.

## 5. Prompt Design

System prompt for the intake bot:

```
You are Bee's intake assistant. Your job is to review a user's request and ensure it is clear, complete, and actionable before it is sent to the worker agent for execution.

You will receive the user's original request (either typed text, pasted content, or extracted text from an uploaded document).

## Your Process

1. Read the request carefully.
2. Evaluate it against this rubric — identify any gaps:
   - **Scope**: What exactly needs to be done? Is the deliverable clearly defined?
   - **Audience**: Who is the output for? (e.g., academic professor, casual reader, client)
   - **Format**: What format should the output be in? (e.g., Word doc, PDF, slides, plain text)
   - **Language**: What language should the output be in?
   - **Length/depth**: How long or detailed should the output be?
   - **References/sources**: Are there specific sources to use or avoid?
   - **Deadline or priority**: Is there a time constraint?
   - **Edge cases**: Anything ambiguous that could be interpreted multiple ways?
3. If there are gaps, ask clarifying questions. Rules:
   - Ask at most 3 questions per turn.
   - Be concise. Each question should be 1-2 sentences.
   - Offer reasonable defaults the user can accept (e.g., "Should the output be in Vietnamese? If you don't specify, I'll assume Vietnamese.")
   - If the request is already clear and complete, skip straight to producing the final spec.
4. If the user says "just go", "you decide", "skip", or anything indicating they want you to proceed without further clarification, make reasonable assumptions and produce the final spec immediately.

## Output Format

When you have enough information (or the user tells you to proceed), respond with EXACTLY this JSON block and nothing else:

\`\`\`json
{
  "ready": true,
  "summary": "One-sentence summary of what will be done",
  "original_request": "The verbatim original request or a faithful summary if it was very long",
  "clarifications": [
    {"question": "What you asked", "answer": "What the user said"}
  ],
  "final_spec": {
    "task": "Clear description of the task",
    "audience": "Who the output is for",
    "format": "Output format",
    "language": "Output language",
    "length": "Expected length or depth",
    "references": "Any sources or constraints",
    "deadline": "If mentioned, otherwise null",
    "notes": "Any other relevant details"
  }
}
\`\`\`

Until you are ready to produce the final spec, respond conversationally with your clarifying questions. Do NOT include the JSON block in intermediate responses.
```

The function detects `done` by checking whether the Gemini response contains `"ready": true` in a JSON code block. If it does, the function parses the JSON, stores it as `finalSpec` on the session document, and returns `done: true` to the client.

## 6. Frontend Integration

**New component: `BeeIntake.vue`** (sibling to existing `BeeHome.vue`, `BeeJob.vue`, `BeeHistory.vue`).

Responsibilities:
- Chat-style UI: scrollable message list, input field at bottom.
- Messages rendered with role indicators (bot avatar for Gemini, user avatar for Haruka).
- File upload preserved — the existing upload flow feeds into the intake session instead of directly creating an issue.
- Typing indicator: shown while awaiting Cloud Function response (the `beeIntakeTurn` call).
- "Send to Bee" button: **disabled** until `done === true` (session has a `finalSpec`). Once enabled, clicking it calls `beeIntakeSubmit`.
- "Skip intake" link: sends "just go" as a user message, triggering immediate spec generation.
- Localization: all static strings via existing i18n setup. Bot messages come from Gemini and are not translated (Gemini responds in the language Haruka uses).

Integration with routing:
- `BeeHome.vue` gains a new initial state: instead of immediately showing the upload-and-submit flow, it shows the intake chat after upload/text input.
- After "Send to Bee" succeeds, redirect to `BeeJob.vue` as today.

## 7. Issue Body Format

When `beeIntakeSubmit` fires, the GitHub Issue body is constructed from the session data:

```markdown
## Request Summary
{finalSpec.summary}

## Original Request
{originalRequest — truncated to 2000 chars if longer, with note}

## Clarification Q&A
{For each clarification:}
**Q:** {question}
**A:** {answer}

## Final Specification
- **Task:** {finalSpec.task}
- **Audience:** {finalSpec.audience}
- **Format:** {finalSpec.format}
- **Language:** {finalSpec.language}
- **Length:** {finalSpec.length}
- **References:** {finalSpec.references}
- **Deadline:** {finalSpec.deadline}
- **Notes:** {finalSpec.notes}

---
_Intake session: {sessionId} | Turns: {turnCount} | Intake completed_
```

If intake was skipped (fallback), the body includes:

```markdown
## Original Request
{raw request text or "[See attached file]"}

---
_Intake skipped — original request filed as-is_
```

## 8. Failure Modes

| Failure | Detection | Fallback |
|---------|-----------|----------|
| Gemini API down / 5xx | HTTP error from `@google/generative-ai` | Return error to client. Client shows "Intake unavailable — you can submit directly." Button becomes enabled for direct submission (skip intake). |
| Gemini rate-limited (429) | HTTP 429 | Retry once after 2s. If still 429, same fallback as above. |
| Gemini returns malformed response | JSON parse failure on `finalSpec` | Retry once with explicit instruction "Respond with the JSON spec only." If still malformed, log error, mark session `error`, allow direct submission. |
| Cloud Function timeout (60s default) | Function timeout | Client sees generic error. Increase function timeout to 120s for intake functions. |
| File too large to extract | `mammoth` throws or text exceeds 30k chars | Truncate with note. If mammoth fails entirely, skip file content and ask user to describe the request in text. |

## 9. Cost Guardrails

| Guardrail | Limit | Enforcement |
|-----------|-------|-------------|
| Input tokens per session | 50,000 | Function tracks `totalInputTokens` on session doc. If a turn would exceed, function returns `done: true` with whatever spec it can produce + a note that the token budget was reached. |
| Output tokens per turn | 2,000 | Set in Gemini API call `maxOutputTokens`. |
| Output tokens per session | 5,000 | Function tracks `totalOutputTokens`. Same enforcement as input. |
| Max conversation turns | 8 | Function checks `turnCount`. At turn 8, function appends "Please provide your final specification now." to the prompt and forces `done: true` on the response. |
| Daily sessions per user | 20 | Function queries `bee-intake-sessions` where `uid == caller && createdAt > today`. If >= 20, reject with "Daily limit reached." |

Token counts come from the Gemini API response metadata (`usageMetadata.promptTokenCount`, `usageMetadata.candidatesTokenCount`).

## 10. Privacy

**Data sent to Google Gemini API:**
- Extracted text content from uploaded `.docx` files.
- User-typed text input.
- Clarification Q&A messages.
- System prompt (no user data).

**Data NOT sent:**
- Firebase Auth tokens or credentials.
- User email or PII beyond what is in the document content itself.
- File binary — only extracted text.

**Google's data handling:** Gemini API (paid tier) does not use API input/output for model training per Google's API terms. Data is processed and discarded. No explicit data retention opt-out is needed for the API tier, but this should be documented for Haruka's awareness.

**Firestore retention:** Conversation data in `bee-intake-sessions` is retained per the cleanup policy in Section 3. Haruka can request deletion of specific sessions.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                    Frontend (Vue)                     │
│                                                       │
│  BeeHome.vue ──> BeeIntake.vue ──> BeeJob.vue        │
│       │              │    ▲                            │
│       │         chat UI   │ done=true                  │
│       │              │    │                            │
│       └──upload──────┘    │                            │
└──────────────────────────│────────────────────────────┘
                           │ callable functions
                           ▼
┌─────────────────────────────────────────────────────┐
│              Cloud Functions (apps/functions/)        │
│                                                       │
│  beeIntakeStart ──┐                                   │
│  beeIntakeTurn  ──┼── Gemini 2.5 Flash               │
│  beeIntakeSubmit ─┘   (@google/generative-ai)        │
│       │                                               │
│       ├── Firestore: bee-intake-sessions              │
│       ├── Storage: bee-temp (read .docx)              │
│       └── GitHub: file issue (Octokit)                │
└───────────────────────────────────────────────────────┘
                           │
                           ▼
┌───────────────────────────────────────────┐
│         GCE bee-worker (e2-micro)          │
│    Polls GitHub Issues, runs Claude        │
│    Sees: final spec + Q&A + original       │
└───────────────────────────────────────────┘
```

## Acceptance Scenario

1. Haruka opens `/yourApps/bee` and uploads `research-request.docx` which contains: "I need a summary of recent papers on transformer architectures."
2. The intake bot reads the extracted text and responds:
   - "I see you want a summary of recent papers on transformer architectures. A few questions:
     1. What audience is this for — academic (formal citations) or personal learning (casual)?
     2. How many papers should I cover, and from what time range?
     3. Should the output be in Vietnamese or English?"
3. Haruka replies: "For my professor, last 2 years, English, about 10 papers, in Word format."
4. The bot responds with the JSON final spec:
   - summary: "Literature review of ~10 transformer architecture papers from 2024-2026 for academic audience"
   - format: "Word document (.docx)"
   - language: "English"
   - length: "~10 papers, detailed summaries"
   - audience: "Academic professor"
5. "Send to Bee" button activates. Haruka clicks it.
6. GitHub Issue is filed with the full body (original request + Q&A + final spec).
7. Bee-worker picks up the issue and works from the clarified spec.

## Phasing

### P0 — MVP (text-only intake)
- Three Cloud Functions (`beeIntakeStart`, `beeIntakeTurn`, `beeIntakeSubmit`).
- Text input only (no file reading). Haruka types or pastes the request.
- Firestore session management with `messages` subcollection.
- `BeeIntake.vue` chat UI with typing indicator and "Send to Bee" gate.
- System prompt with rubric-based gap analysis.
- Fallback: skip intake on Gemini errors.
- Turn limit (8) and daily session limit (20).

### P1 — File reading
- `mammoth` integration for `.docx` text extraction in `beeIntakeStart`.
- Token budget enforcement (50k input, 5k output per session).
- Truncation handling for large documents.

### P2 — Cost and observability
- Token usage dashboard (read from Firestore session data, display in `BeeHistory`).
- Per-session cost estimation.
- Alerting if daily token spend exceeds threshold (Cloud Function scheduled check or Firestore-triggered).
- Conversation quality review: periodic manual review of completed sessions to tune the system prompt.

## Non-Goals

- Multi-user support beyond `harukainguyen1411@gmail.com` (Bee is currently single-user scoped).
- Voice input or streaming TTS.
- Model fine-tuning.
- Real-time streaming of Gemini responses (callable functions return complete responses; streaming adds complexity with no meaningful UX benefit for short messages).
- Intake for non-docx file types (PDF, images) — can be added later but out of scope.

## Open Questions

1. **Gemini API key:** Does Duong already have a Gemini API key, or does one need to be created? Which GCP project should it live in?
2. **Cloud Functions billing:** The existing Firebase project is on the free Spark plan. Cloud Functions v2 callable functions require the Blaze (pay-as-you-go) plan. Is the project already on Blaze, or does this need upgrading?
3. **Bee-worker issue parsing:** The bee-worker currently parses issue bodies in a specific format. The new structured body format needs to be compatible with however the worker extracts the task. What does the current parser expect?
4. **Haruka's awareness:** Should the intake bot introduce itself, or does Haruka already know about this feature? (Affects the first-message UX.)
