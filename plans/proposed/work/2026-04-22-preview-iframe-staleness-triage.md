---
status: proposed
orianna_gate_version: 2
complexity: quick
concern: work
owner: karma
created: 2026-04-22
target_branch: feat/demo-studio-v3
tags:
  - demo-studio-v3
  - preview
  - bug
  - triage
  - work
tests_required: true
---

# Preview iframe staleness — triage + targeted fix

## Context

The `demo-preview` remote service renders the Allianz template regardless of current S2 session state. <!-- orianna: ok -- demo-preview is a Cloud Run service name, not a filesystem path --> Chat works end-to-end on the `feat/demo-studio-v3` branch <!-- orianna: ok -- git branch ref, not a filesystem path --> (see sibling plans under `plans/proposed/work/` for the chat-bubble-render and chat-sse-deadlock fixes), but the preview iframe never reflects the session brand. Fresh sessions explicitly configured for Aviva or Lemonade still render Allianz chrome.

Three plausible root causes, none pre-decided:

- H1 (S2 seeding) — the `tools/demo-config-mgmt/` in-memory runtime <!-- orianna: ok -- path under ~/Documents/Work/mmp/workspace/company-os/, not strawberry-agents --> seeds every new session with an Allianz-template default and never overwrites on brand selection, so the config S2 returns is always-Allianz by construction.
- H2 (demo-preview cache) — the remote preview service has a cache (module-level dict, Cloud Run container warm state, or upstream CDN) keyed on something stale and serves the first-seen brand to every subsequent request.
- H3 (studio.js refreshPreview wiring) — the iframe `src` or `postMessage` never updates on brand change. Either `refreshPreview()` is never called after brand selection, or it is called but reloads a URL that omits the session ID and brand param.

The goal of this plan is to triage first, fix second: reproduce deterministically, identify which of H1 / H2 / H3 is root (they are not mutually exclusive, but only the dominant cause gets fixed in this slice), then ship a narrow fix on the god branch. North Star P2 — preview must show live session changes.

## Non-goals

- No redesign of the S2 config schema or preview-service protocol.
- No cross-touch with PR #65 (dashboard-split) or PR #32 (firestore-fix). Those threads stay independent.
- No cache-layer rewrite; if H2 turns out to be a CDN or edge cache we patch cache keys, we do not re-architect.
- No new brand templates; the preview service template inventory is out of scope.

## Tasks

### T1 — xfail regression test pinning the invariant

- kind: test
- estimate_minutes: 25
- files: `tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` <!-- orianna: ok -- prospective path under work workspace -->
- detail: Playwright-driven test. Step one, create a fresh session via `POST /session`. Step two, drive the chat to commit a non-Allianz brand such as Aviva. Step three, wait for the studio page to settle. Step four, read the preview iframe rendered DOM or its `src` attribute plus a fetch of that URL, and assert the brand string is Aviva, not Allianz. Mark the test with `@pytest.mark.xfail` pointing at this plan file until T4 flips it.
- DoD: test runs red and xfail locally via `pytest tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py -q`; commit lands on the god branch before any fix commit (Rule 12).

### T2 — Triage: reproduce and capture evidence for all three hypotheses

- kind: investigation
- estimate_minutes: 45
- files: `assessments/qa-reports/2026-04-22-preview-iframe-staleness-triage.md` <!-- orianna: ok -- prospective report path under strawberry-agents -->
- detail: Single triage pass, three probes in order. Probe one for H1 — boot S2 locally, `POST /session` then `GET /config` for the session; inspect returned brand both immediately after session create and after a brand-change turn; log both payloads. Probe two for H2 — hit the demo-preview service directly bypassing studio.js with two back-to-back requests carrying different session IDs and brand params; compare rendered HTML; additionally hit the same URL twice to check for container-warm cache. Probe three for H3 — open the studio page in Playwright, select a non-Allianz brand, snapshot the iframe element via `src` attribute, `data-*` attrs, and the `postMessage` log captured through Playwright console hooks; verify whether `refreshPreview()` fires at all, and with what URL. Classify root as H1, H2, H3, or combination; pick the dominant one for T3 and T4.
- DoD: triage report saved, commits reference it; the report final section names the dominant hypothesis with supporting log snippets and the chosen fix branch from the decision tree below.

### T3 — Apply narrow fix on the dominant hypothesis branch

- kind: fix
- estimate_minutes: 40
- files: depends on T2 outcome — one of the following targets, all within the work workspace. H1 target — `tools/demo-config-mgmt/` session-seeding code, likely a default-template or seed-session code path. <!-- orianna: ok -- prospective path under work workspace --> H2 target — `tools/demo-preview/` cache layer. <!-- orianna: ok -- prospective path under work workspace --> H3 target — `tools/demo-studio-v3/static/studio.js`. <!-- orianna: ok -- path under work workspace -->
- detail: Implement the minimum change that makes T1 xfail flip to pass. Keep the blast radius single-file where possible. For H1, stop seeding Allianz as default, or make the seed honor the brand param on session create. For H2, invalidate the cache on session-id boundary, or remove the offending memoization. For H3, wire `refreshPreview()` to the brand-change handler and ensure the iframe URL carries the session ID and brand. No speculative fixes for the two non-dominant hypotheses — log those as follow-ups in the triage report.
- DoD: diff is under ~80 LOC, confined to the chosen branch domain; existing unit tests for the touched service still pass; the commit is prefixed `fix(demo-studio-v3):` and lands on the god branch.

### T4 — Flip xfail to pass and live smoke verification

- kind: test
- estimate_minutes: 20
- files: `tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` <!-- orianna: ok -- same file as T1, under work workspace -->
- detail: Remove the xfail marker so the test runs as a required regression. Run the full Playwright live-smoke — fresh session, select Aviva, assert iframe renders Aviva within 10 seconds; repeat for Lemonade to confirm it is not just "anything but Allianz". Save a screenshot to `assessments/qa-reports/2026-04-22-preview-iframe-staleness-live.png`. <!-- orianna: ok -- prospective screenshot path under strawberry-agents -->
- DoD: pytest green for the regression test; live smoke screenshot attached; commit prefixed `test(demo-studio-v3):` on the god branch.

## Hypothesis branches — decision tree

After T2, the dominant hypothesis dictates the T3 patch shape:

- If H1 dominates, that is S2 returns Allianz regardless of brand arg, patch S2 seeding.
- If H2 dominates, that is demo-preview serves cached HTML independent of session, patch preview cache keying.
- If H3 dominates, that is the iframe src never updates, patch the studio.js brand-change handler.
- If two co-contribute (for example H1 plus H3), fix only the dominant cause; open a follow-up plan for the secondary. Do not fold multiple fixes into one commit.

Author's prior (low-confidence, to be validated by T2): H3 is the likeliest dominant cause. Rationale — chat works end-to-end including brand-aware responses, which suggests S2 is storing and returning brand state correctly (H1 unlikely). The preview service being a separate remote service argues for a client-side wiring gap rather than a server-side cache, since a per-container cache would still vary across request-scoped fetches. The most common failure mode for iframe-backed previews in SPAs is exactly "src never gets recomputed on state change" — a forgotten effect or handler wiring. This is explicitly a prior to disprove, not a shortcut around T2.

## Test plan

Invariants this plan tests protect (all exercised by the T1 and T4 regression tests):

- Inv-PREVIEW-1: Given a session bound to brand B, the preview iframe DOM contains brand B chrome, logo, and wordmark, and does NOT contain any other brand chrome.
- Inv-PREVIEW-2: Changing brand from B1 to B2 mid-session causes the iframe to render B2 within 10 seconds without a full page reload (or with a reload, if that is the chosen mechanism, provided the `src` carries B2).
- Inv-PREVIEW-3: Two concurrent sessions with different brands must not cross-contaminate; session A preview stays on brand A regardless of session B state. This covers the H2 cache-key regression class.

T1 asserts Inv-PREVIEW-1 on a fresh Aviva session. T4 additionally asserts Inv-PREVIEW-2 (Aviva then Lemonade in the same session) and Inv-PREVIEW-3 (two parallel Playwright contexts, one Aviva one Lemonade, cross-check).

Per Rule 12: T1 lands xfail on the god branch before T3 (the fix commit). Per Rule 13: this is a bug fix, so T1 plus T4 together satisfy the regression-test requirement on the same branch as the fix.

## Risks

- Dominant hypothesis misidentified in T2, so T3 fix lands but T4 still fails. Mitigation: T2 report must include the reproduction-before-fix evidence; if T4 is red, revert T3 and re-triage.
- The demo-preview service may be a closed or external deployment we cannot patch from this workspace. If H2 dominates and the fix requires a deploy we do not control, park T3 as an escalation to Azir or Swain and keep T1 xfail'd with an updated reason pointer.
- Playwright flakiness on iframe cross-origin DOM reads. Mitigation: prefer asserting on the iframe `src` URL plus a direct fetch of that URL, over reading the iframe document.

## Out of scope

- Preview template catalog changes.
- S2 persistence (it remains in-memory per the current architecture).
- CDN or edge-cache architecture changes.
- Any cross-touch with PR #65 or PR #32.

## References

- Sibling plans on the same god branch: chat-bubble-render-fix and chat-sse-deadlock-fix, both in `plans/proposed/work/`. <!-- orianna: ok -- directory exists; individual plan filenames intentionally not cited as tokens here -->
- North Star P2: preview shows live session changes.
