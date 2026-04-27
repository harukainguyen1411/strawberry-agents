---
slug: bring-demo-studio-live-e2e-v1
status: active
concern: work
scope: [work]
owner: duong
created: 2026-04-27
deadline: TBD
claude_budget: resourceful
tools_budget: limited
risk: moderate
user: duong-only
focus_on:
  - end-to-end user flow on prod
  - reliability of the build and verify pipeline
  - clean handoff between agent chat and non-agent backend triggers
less_focus_on:
  - multi-user / multi-tenant scenarios
  - non-default brand templates beyond what default config exercises
related_plans: []
---

## Goal

Bring the Demo Studio fully live on production for a single end-user (Duong) running a complete demo creation flow without manual intervention. The user signs in, sees a usable default config with live preview, edits via natural-language chat with the demo agent, triggers a Build, watches Build → Verify run with live progress, and ends with a working demo link they can share. The goal is the *end-to-end happy path* on prod, validated by the user, not a feature checklist.

## Definition of Done

The following user-flow steps all work against the production demo-studio service, end-to-end, in a single session, without agent or operator intervention beyond the user's own clicks and chat messages:

1. **Sign-in** — User signs in via Firebase Auth (Google) and lands in the studio.
2. **Session creation** — User creates a new session.
3. **Default config greeting** — On entering the new session, the user is greeted with a fully built default config and a live preview attached to that config.
4. **Chat with demo agent** — User chats with the demo agent. The agent uses the **vanilla Anthropic Messages API with client-side tool dispatch** (not the Anthropic managed-agent feature).
5. **Live config refresh** — Agent-driven config changes refresh the preview live (no manual reload).
6. **Build trigger** — A "Build project" button (UI control, **not** an agent tool call) triggers Build factory S3.
7. **Live build progress** — The user can watch the build process live with a visible progress bar.
8. **Build completion notification** — The user is notified when the build completes, both via chat (agent message) and a UI state change.
9. **Auto-verify** — Verification service starts immediately after build completes, triggered by an API call (**not** an agent tool call). No prompt required from the user.
10. **Live verify progress** — The user can watch verification progress live with a visible progress bar.
11. **Final result + handoff** — When verify completes, the agent tells the user the result, the project ID, and the demo link in chat. The flow ends here.

The DoD is met when Duong runs the above flow on prod once successfully and Akali validates the same flow via Playwright with screenshots and video at every step.

## Constraints

- **Concern:** work; production deploy on `demo-studio-v3` Cloud Run service.
- **Scope:** single-user happy path. No multi-user, no auth-domain expansion beyond `missmp.eu`.
- **Anthropic surface:** vanilla Messages API + client-side tool dispatch — no Anthropic managed-agent. This is already the architectural direction of PR #32 / `feat/demo-studio-v3`.
- **Triggers:** Build and Verify start from button-click and API-call respectively, not agent tool calls. The agent observes and narrates; it does not initiate Build or Verify.
- **Risk:** moderate — touches deployed surface, end-to-end flow, real Anthropic API calls.
- **Budget:** resourceful Claude budget, limited tools budget. Standard pace.
- **Deadline:** TBD — Duong sets cadence.

## Decisions

### 2026-04-27 — ADR sequencing

ADRs land in this order (Duong, 2026-04-27). Each is a separate ADR with its own plan, breakdown, test plan, and qa_plan. PR target stays `feat/demo-studio-v3`; PR #32 stays open and merges into `main` last, after all DoD steps green on the feat branch.

1. **ADR-1: Build progress bar** — backend progress emission (factory S3) + UI surface + observation contract. Step 7 of DoD.
2. **ADR-2: Verification service** — service definition, API surface, progress reporting, post-build trigger. Steps 9–10 of DoD. Highest pre-build unknown.
3. **ADR-3: Default-config greeting** — new-session creation flow, default-config template source, preview attachment at session creation. Steps 2–3 of DoD.
4. **ADR-4: Async agent notifications** — agent message injection on build/verify state changes; chat-side push or poll mechanism; final-result handoff. Steps 8 + 11 of DoD.
5. **ADR-5: Conflict / sanity sweep** — confirms no agent-tool registration conflicts on Build (#6) and Verify (#7), final demo-link URL contract (#9), any remaining uncertainty cleanup. Smaller scoped ADR(s) as needed.
6. **PR #32 merge into `main`** — final step, only when all five ADRs are landed on `feat/demo-studio-v3` and Akali validates the full E2E happy path against the feat-branch deployment.

Each ADR carries its own `qa_plan: required` with a fully-written Akali test script: per-step Playwright actions, screenshot checkpoints, pass/fail criteria, env URL, sign-in path, browser-environment isolation (incognito vs persistent). Akali's RUNWAY scope-gap on 2026-04-27 (she validated F1+F2 but bypassed sign-in via nonce URLs) is the trigger learning for this requirement.

## Out of scope

- Multi-user, multi-tenant, RBAC, share-with-others.
- Brand templates beyond the default config + agent-edited variants.
- Mobile / responsive UI beyond what the existing Studio offers.
- Persistence of demo projects beyond the session lifetime (out of v1).
- Failure-mode UX for build/verify failures (the v1 DoD targets the happy path; failure UX is a follow-up project).
- Self-serve account creation outside the Firebase auth-domain allowlist.
