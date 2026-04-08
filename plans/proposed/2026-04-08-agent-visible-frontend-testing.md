---
title: Agent-Visible Frontend Testing — Closing the Loop Between Edit and See
status: proposed
owner: bard
created: 2026-04-08
---

# Agent-Visible Frontend Testing

> *A chime, low and sustained.* The agents write into a room they cannot enter. They hear the walls but never see the paint. This plan gives them eyes — just enough to tell if the door they hung is crooked.

## Problem

When a Sonnet agent edits myapps' Vue frontend, it verifies with typecheck and unit tests and hopes. It cannot tell whether a button is off-center, a modal overlaps the nav, a dark-mode style is missing, or the whole page crashed to a white screen. Every visual regression has to be caught by Duong eyeballing the preview tunnel, which is the exact loop the autonomous delivery pipeline is trying to remove from him.

The question is not "can we test frontends" — myapps already has Playwright with 6 specs and Vitest unit tests. The question is: **what primitive does a Sonnet agent, running inside a Claude Code subagent, use to literally observe the page it just edited, and where in the edit→PR→preview loop does that observation happen?**

This plan is architecture-level. It names the tools, ranks them, picks an MVP, and slots the verification step into Syndra's autonomous delivery pipeline. It does not specify code. It does not pick implementers.

## Scope

In scope:
- Enumerating the visibility primitives an agent can use and ranking them by bug-catch value per token/disk/time cost.
- Surveying existing MCP servers for browser/Playwright/Storybook control and rating them against Claude Code's subagent model.
- Proposing how the agent reuses the existing Playwright install rather than bolting on a parallel headless stack.
- Picking where in the delivery pipeline the self-verification step lives.
- A minimum viable slice and a phased ramp.

Out of scope:
- Implementation code.
- Changes to the existing Playwright spec suite itself.
- Any rewrite of the CI pipeline — the agent's self-verification *augments* CI, it does not replace it.
- Visual design review (is the UI *pretty*) — only regression/crash/layout-break detection.

---

## 1. Visibility primitives an agent actually needs

An agent "seeing" the frontend breaks into seven distinct primitives. Each catches a different class of bug and costs a different amount.

| # | Primitive | What the agent consumes | Catches | Cost (time / disk / tokens) | Verdict |
|---|---|---|---|---|---|
| 1 | **Screenshot (PNG, full page)** | PNG → multimodal vision | White-screen crashes, misaligned layout, obviously broken styling, wrong page rendered | ~1-3s per shot; ~100-400KB; ~1.5k tokens per image | **Must have.** This is the anchor primitive. |
| 2 | **DOM snapshot (serialized HTML)** | Text | Missing elements, wrong text, broken data binding, conditionally-rendered bugs | <1s; a few KB; text tokens cheap | **Must have.** Cheap, complements screenshots. Answers "is the button there at all" without a PNG. |
| 3 | **Accessibility tree dump** | Structured text (ARIA roles, labels, hierarchy) | Semantic / a11y regressions, wrong landmarks, screen-reader breakage | <1s; small; cheap | **Nice to have.** Playwright exposes this (`page.accessibility.snapshot()`) — free if we already have Playwright up. |
| 4 | **Console + network logs** | Text (stdout + failed requests) | Runtime JS errors that slip past typecheck, CSP violations, 404s on assets, Firebase auth failures | <1s; small; cheap | **Must have.** Catches the "build passed, page crashed on mount" class that a screenshot also catches but a log explains *why*. |
| 5 | **Visual regression diff (before/after screenshot comparison)** | "X pixels changed at region Y" + optional diff PNG | "I didn't intend to change this page but I did" | +1 shot per check; disk grows; cheap in tokens (report is text, PNG only loaded on flag) | **Phase 2.** Requires a baseline library and tolerance tuning. High value once it exists but not MVP. |
| 6 | **Playwright trace (timeline + screenshots + network + DOM)** | .zip artifact; agent opens specific frames | Everything — this is the fullest debugging artifact | 5-20s per run; multi-MB; only consumed on failure | **Must have on failure only.** Don't load into context by default; load on red. |
| 7 | **Component-level isolation (Storybook/Histoire)** | Single component rendered in isolation, screenshot + DOM | Component-in-isolation bugs without spinning up the whole app, auth, and Firestore | High setup cost; per-shot cost low | **Phase 3 / optional.** See §6. |

**Recommended MVP bundle (covers ~80% of visual bugs):**

1. Full-page screenshot of the page the agent touched (primitive 1)
2. DOM snapshot of the same page (primitive 2)
3. Console + network error log for that page visit (primitive 4)
4. Playwright trace, produced always but only read by the agent on failure (primitive 6)

These four come free from a single Playwright `page.goto()` + `page.screenshot()` + `context.tracing.start()` sequence. They are not four separate tools; they are four outputs of one tool call.

---

## 2. MCP servers to evaluate

This is the critical question: does a clean off-the-shelf MCP server exist for browser inspection, or do we wrap Playwright ourselves?

Candidates to explicitly investigate during approval → implementation:

| Candidate | What it is | Likely fit for Claude Code subagent | Risk |
|---|---|---|---|
| **`@modelcontextprotocol/server-playwright`** (Microsoft/community) | A published MCP server that exposes Playwright actions (navigate, screenshot, click, snapshot) as MCP tools | High — this is the most promising. Microsoft has been publishing Playwright MCP servers in this space. Needs verification of current state and whether it returns screenshots as resources the agent can read multimodally. | May need localhost whitelisting / URL restrictions; auth story unclear for Firebase-gated pages |
| **Puppeteer MCP server** (Anthropic reference impl) | One of the original reference MCP servers | Medium — works but Puppeteer lags Playwright on tracing/a11y dumps, and myapps is already on Playwright so we'd be introducing a second browser automation stack | Drift — maintaining two browser stacks is wasteful |
| **Chrome DevTools Protocol (CDP) MCP** | Raw CDP wrapper | Low — too low-level, agents would reinvent Playwright-style ergonomics | High complexity |
| **browser-use / browser-automation MCP** (community) | High-level autonomous browser control with LLM in the loop | Low — optimized for agent-driven *exploration* (click around the web), not agent-driven *verification* (render this one URL and show me). Overkill. | Wrong tool for the job |
| **Storybook/Histoire MCP** | Component-level inspection | Does not appear to exist as a maintained MCP server today (verify) | Would need custom build; deferred to §6 |
| **Custom thin wrapper: `mcps/browser-inspect/`** | Our own MCP server wrapping Playwright CLI, exposing one tool: `inspect_page(url) → {screenshot_path, dom, console_log, network_log, trace_path}` | High — we control the interface, we bound the surface area, and we reuse the existing `@playwright/test` install | Maintenance burden is on us (but small — Playwright already installed, this is glue) |

**Recommendation — primary path:** Adopt the Playwright MCP server if a mature published one exists and its screenshot output is agent-readable. If not (or if it's too broad and exposes click/type/keyboard tools that agents don't need for *verification*), build `mcps/browser-inspect/` as a thin custom MCP with one read-only tool: `inspect_page`. Do not introduce Puppeteer.

**Rationale for the thin-custom fallback:** myapps already depends on Playwright. A custom wrapper reuses that dep, has a surface area of one tool, is auditable, can be localhost-only by default, and avoids the risk of an agent wandering off to `click()` something on a live Firestore DB.

Investigation tasks for the implementer:
- Enumerate published Playwright MCP servers, pick the most maintained, test one end-to-end with a subagent.
- If the MCP route is blocked (maturity, auth, or Windows compatibility), fall back to shelling Playwright CLI from a bash tool call — the primitives are the same, only the transport differs.

---

## 3. Integration with the existing Playwright setup

myapps already has Playwright 1.58.0 installed with 6 specs. The plan reuses it in three ways:

**3a. Verification spec — a new Playwright file the agent runs.**
Add one spec (e.g. `e2e/agent-verify.spec.ts`) whose job is not assertion but *observation*: it visits a list of URLs (passed via env var or fixture), takes a full-page screenshot, dumps DOM and console logs, and writes them to a known directory. The agent then reads those artifacts directly from disk. This is the cheapest way to get the four MVP primitives without any new dependency.

**3b. Trace-on-failure for the existing 6 specs.**
Enable `trace: 'retain-on-failure'` in `playwright.config.ts` if not already. When an existing spec fails in CI or locally, the agent has a rich artifact to read instead of guessing.

**3c. Separate "verification run" from "test run" in the agent workflow.**
The existing `npm run test:e2e:ci` runs the assertion suite. The agent should invoke a new `npm run verify:frontend` (or equivalent) that runs *only* the observation spec and is fast (<15s). The assertion suite still runs in CI independently. The agent does not need to run all 6 specs locally per edit — that's too slow and too noisy.

**Question for Duong / implementer:** does the existing Playwright config already produce traces on failure? The plan should confirm and, if not, add that as a one-liner config change.

---

## 4. Where in the delivery pipeline does visual self-verification happen?

Syndra's autonomous delivery pipeline plan (in parallel — plans/proposed/2026-04-08-autonomous-delivery-pipeline.md, read before implementing this) defines a loop: Discord → issue → agent edit → PR → preview deploy → tunnel URL to Duong.

The options:

- **(a) Before the PR — agent self-checks in local dev only.** Fast loop, no deploy needed, agent runs `npm run dev` or Playwright against a local preview. **Pro:** catches bugs before a PR is even opened, keeps Duong's PR queue clean. **Con:** local env may not match preview (Firebase secrets, build-time env vars).
- **(b) On the PR preview only.** Agent waits for the preview deploy, then runs Playwright against the preview URL. **Pro:** matches what Duong will see in the tunnel. **Con:** slower loop; agent can't iterate without cutting a new PR commit.
- **(c) Both.** Local self-check before PR + preview self-check before Discord notification. **Pro:** catches most bugs cheaply at (a), escalates to (b) only for env-specific bugs. **Con:** two sets of tooling to maintain.
- **(d) Neither — rely on Duong to eyeball the tunnel.** **Pro:** zero setup. **Con:** is literally the problem this plan exists to solve.

**Recommendation: (c) — both, but with asymmetric weight.**

- **Local (a) is the primary loop.** Agent runs Playwright against a local `vite preview` or `vite dev` instance after each edit. Fast, free, catches 80% of bugs (crashes, layout break, missing components). This is the tight inner loop.
- **Preview (b) is a gate.** Before the agent posts the tunnel URL to Discord, it runs the same verification spec against the preview URL once. This catches the "worked locally, broke in preview" class — wrong Firebase env var, build minification issue, hosting rewrite misconfigured.
- **(d) is the final backstop** — Duong still eyeballs the tunnel. The goal isn't to remove him from the loop, it's to make sure he only sees PRs that already render.

Cost: one extra Playwright run per edit (seconds) plus one extra Playwright run per PR before the Discord ping (seconds). Acceptable.

---

## 5. Developer ergonomics — Duong's own use

Everything proposed should work for Duong too, not just for agents. Specifically:

- `npm run verify:frontend` should be a plain npm script Duong can run himself to sanity-check a branch before a commit.
- Screenshot output goes to a known gitignored directory (e.g., `apps/myapps/.verify/`) that Duong can open in an image viewer.
- The MCP `inspect_page` tool (if we build one) should also be callable from a bash script so Duong doesn't need an MCP client to trigger it.
- Trace viewer: Duong already has Playwright trace viewer (`npx playwright show-trace`) — we don't duplicate that; we just make sure the agent's run writes traces Duong can open with that command.

**Where the agent diverges from Duong:** agents benefit from the DOM snapshot as text (they can grep it); Duong doesn't need that file because he reads the screenshot directly. The DOM dump is agent-specific output and can be gated behind a `--dom` flag or an env var.

---

## 6. Storybook / Histoire — add or skip?

myapps has no component-level isolation today (confirmed from snapshot — Vite + Vue + Tailwind, no Storybook/Histoire in deps).

**Recommendation: skip for MVP, revisit in Phase 3.**

Reasons to skip now:
- Setup cost is real — Histoire integration with a Vue 3 + Tailwind + Pinia + Firebase app needs mocking strategy for auth and Firestore, and that's exactly the kind of yak-shave that stalls plans.
- The 80% of bugs agents miss today are full-page bugs (crashes, layout, wrong data), not isolated-component bugs. Full-page Playwright screenshots catch those.
- Adding Histoire later is cheap once the verification loop is proven to add value.

Reasons to revisit later:
- Once the verification loop is stable and agents start editing individual widgets (e.g., the Task List category chip), component isolation lets them iterate faster without loading the whole app + auth + Firestore.
- Histoire/Storybook also gives Duong a visual component catalog, which is genuinely useful for his own dev work.

**Decision gate for Phase 3:** revisit after 2 weeks of the verification loop being live. If agents are repeatedly burning time booting the full app for single-widget changes, add Histoire. If not, defer indefinitely.

---

## 7. Cost and failure modes

**Disk / memory per agent invocation:**
- Playwright + Chromium is already installed (no new cost).
- Per screenshot: ~100-400KB PNG. Per trace: ~1-5MB zip.
- Per verification run: ~5-10MB total. Garbage-collect a `.verify/` directory older than N runs.
- Memory: Chromium headless ~200-400MB during the run; released after. Acceptable on Duong's Windows box as long as we don't run parallel verifications for multiple agents at once.

**Port collision — dev server already running:**
- Risk: Duong is running `npm run dev` on port 5173, agent starts its own Playwright verification using `vite preview` which defaults to 4173 — usually fine.
- Mitigation: verification spec should target a configurable URL (env var `VERIFY_URL`, default `http://localhost:4173`), and the npm script that boots the preview should probe-and-bail if port is taken, falling back to pointing at the already-running dev server on 5173.
- Explicit in plan: no automatic killing of Duong's dev process, ever.

**Dev server crashed / 404 / wrong page:**
- The screenshot will literally show "This site can't be reached" or a 404. The agent's verify spec must assert `response.status() === 200` and fail loud if not — the screenshot is a confirmation, not a proof-of-life.
- Console log will show network errors; the agent reads those before trusting the screenshot.

**Multimodal token cost of screenshots:**
- ~1.5k tokens per image on Claude. For a single verification run reading 1-3 screenshots, cost is ~2-5k tokens. Affordable per edit.
- For visual-regression diffing (phase 2), only read the diff image *if there's a diff to investigate* — don't multimodal-load baseline + new + diff on every run. Read the text report (pixel delta summary) first; load image only on flagged regression.
- Budget rule: **≤3 screenshots loaded into agent context per edit.** More than that and you're wasting budget on debug loops.

**Localhost/security:**
- Any MCP server or wrapper tool should default to a localhost URL whitelist. Agents should not browse arbitrary internet via the verification tool.
- Preview URL (for pipeline gate (b)) is an explicit exception — it's a known-safe Firebase Hosting preview domain, allow-listed.

**Concurrency:**
- Multiple agents running Playwright simultaneously on the same box will fight for port 4173 and Chromium resources. Serialize via a file lock or unique port per agent. Flagged as an implementation concern, not MVP-blocking.

---

## 8. Minimal viable slice

**MVP — the smallest thing that delivers value:**

1. Add a single Playwright spec `e2e/agent-verify.spec.ts` that:
   - Accepts a list of routes via env var
   - For each route: goto, wait for idle, screenshot, dump DOM, dump console+network, write all four to `apps/myapps/.verify/<route>/`
   - Asserts response 200
2. Add npm script `npm run verify:frontend` that boots `vite preview` (or points at a running dev server) and runs the spec.
3. Update the Sonnet agent playbook (in a separate follow-up plan or as part of Syndra's pipeline plan) to require: after any edit to `apps/myapps/src/`, run `verify:frontend`, read the screenshot + console log, and only open a PR if both are clean.
4. Enable `trace: 'retain-on-failure'` in `playwright.config.ts` (one-line change).
5. Gitignore `.verify/`.

That's the MVP. No new dependencies. No new MCP server. Reuses the existing Playwright install end-to-end. A Sonnet agent can do this today with `Bash` + `Read` tools alone.

**Phase 2 — once MVP proves value:**

- Build or adopt a proper MCP server (`mcps/browser-inspect/` or the community Playwright MCP) so the agent calls one tool instead of juggling npm scripts and filesystem reads.
- Add visual regression diffing (baseline directory + pixel tolerance + report-first, image-on-flag).
- Wire the verification step into Syndra's autonomous delivery pipeline at both (a) local pre-PR and (b) preview pre-Discord gates.

**Phase 3 — only if justified by Phase 2 usage data:**

- Storybook/Histoire for component isolation.
- Parallel-agent concurrency handling (port allocation, file locking).
- Richer bug-pattern detection (e.g., a regex pass over DOM for `[object Object]`, empty `v-for`, unresolved `{{ }}` template bindings).

---

## Open questions for Duong

1. **Which MCP transport?** Preference for adopting a published Playwright MCP server vs. building our own thin wrapper in `mcps/browser-inspect/`? (Recommendation: try published first, fall back to custom, but Duong should know we might own a new MCP.)
2. **Pipeline gate placement (§4):** Comfortable with (c) both local + preview verification? Or start with just (a) local and defer (b) until the pipeline exists?
3. **Storybook/Histoire (§6):** OK with skipping for MVP and revisiting after 2 weeks? Or does Duong have an independent reason to want it now for his own dev work?
4. **Concurrency:** Any near-term scenario where two agents edit myapps frontend in parallel? If not, we can defer the port-locking question.
5. **Firestore/auth for verification runs:** The verification spec will hit pages that expect auth. Do we use the existing `e2e/auth-local-mode.spec.ts` pattern (localStorage mode, no real auth) or stand up a test-account Firebase project for verification? Affects whether visual verification can check the logged-in views or only the public ones.

## Coordination notes

- This plan sits downstream of Syndra's autonomous-delivery-pipeline plan. If that plan lands first and already scopes a verification step, merge this into it rather than running parallel. If this plan lands first, Syndra's plan should reference it at the "self-verify before tunnel" step.
- The MVP (§8 steps 1-5) can ship without waiting for Syndra's plan — it's purely additive to myapps and delivers value even in the current manual-PR workflow.
- No implementer assignment. Evelynn decides after approval.
