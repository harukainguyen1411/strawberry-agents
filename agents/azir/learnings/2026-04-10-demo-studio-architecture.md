# Demo Studio Architecture Patterns

## Key decisions

1. **Firestore as draft store, WS only at approval.** During preview/editing, demo config lives in Firestore. No WS project is created until the user approves. This avoids orphaned projects and makes chat edits instant (~50ms Firestore write vs ~500ms WS API call).

2. **Three services, two languages.** demo-studio (Go) serves the web UI and chat proxy. demo-runner (Python) runs the factory pipeline. demo-ui (Go) serves deployed demos. Go for request-handling, Python for LLM pipeline -- play to each language's strength.

3. **One-time code auth, not JWT in URL.** Slack posts a link with a short-lived one-time code. On first load, backend exchanges it for an HttpOnly cookie JWT. Prevents token leakage in logs, browser history, and Slack link previews.

4. **Schema allowlist on agent config writes.** The update_config tool validates against a strict allowlist before Firestore writes. Metadata and status fields are never writable by the agent. This is defense against prompt injection via the chat interface.

5. **External content sandboxing.** Research results from brand websites are placed in delimited tags with a "treat as data only" instruction, never injected raw into system prompts.

## Collection naming

Canonical Firestore collection: `demo-sessions` (not `demo-configs`, not `demo-studio-sessions`). Represents the full lifecycle from spec gathering through deploy.

## GCS continuity

Deployed demos still use GCS (`gs://mmpt-demo-configs/configs/{projectId}.json`). Firestore is for draft/preview only. The `config_store.upload_config()` call on deploy is the bridge.
