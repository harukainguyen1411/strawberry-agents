---
title: Orianna role redesign — add external freshness check, demote grep-anchor to sanity gate
status: proposed
owner: lux
created: 2026-04-19
supersedes-behavior-of: plans/implemented/2026-04-19-orianna-fact-checker.md
---

# Context

Orianna shipped on 2026-04-19 (`plans/implemented/2026-04-19-orianna-fact-checker.md`)
as an internal fact-checker: for every load-bearing claim in a plan, she
requires a grep-able anchor in the current working tree. She is invoked as a
mandatory gate inside `scripts/plan-promote.sh` (lines 63–86) and as a weekly
memory auditor. Her tool set is Read/Glob/Grep/Bash only — deliberately no
WebSearch, no WebFetch.

That design catches one real failure mode: fabricated or stale *internal*
references. The motivating bug — "Firebase GitHub App" in an Azir plan when
the repo actually uses `FIREBASE_SERVICE_ACCOUNT` key auth — was an internal
drift bug and Orianna's grep gate would have caught it.

What Orianna **cannot** catch is a different, equally expensive class of bug:
the plan cites a **real** external thing, but that external thing has
**changed** since the author's (or the model's) training cutoff. Concretely:

- A deprecated Anthropic SDK method the planner still assumes exists
  (`client.completions.create` vs `client.messages.create`).
- A Next.js, Firebase, or GCP CLI flag that was renamed or removed in a minor
  version bump.
- A "best practice" URL in the plan that now 404s, or redirects to a
  deprecation notice.
- A library `v-next` with a breaking change the plan didn't account for
  (e.g., a v4 → v5 prop rename in a UI lib).
- A cloud service rebrand or sunset (e.g., a service moved regions, changed
  pricing tiers, or was merged into another product).
- An MCP server reference whose transport model changed (stdio → HTTP) or
  whose tool schema was renamed.

Nothing in the current gate can catch any of this. Orianna reads the working
tree; the working tree doesn't know the internet changed.

Duong's ask: reorient Orianna toward **external freshness verification**
against the live internet, while keeping the internal grep-anchor check as a
lighter consistency sanity-pass.

---

# Decisions

Numbered. Each decision is the accepted position; the "Rejected alternatives"
section below captures what was considered and why it lost.

## D1. Orianna does both. Two-phase gate, block-severity only on external.

**Decision:** Orianna runs **two sequential passes** on every plan. Phase 1 is
the existing grep-anchor check (internal consistency). Phase 2 is the new
external-freshness check. Both findings are merged into one report. Only
**block**-severity findings from **Phase 2** (external) halt promotion by
default; Phase 1 blocks are reclassified to **warn** under this redesign (see
D5 for the exception case).

**Rationale:**

- Phase 1 has produced 10+ real reports in one day
  (`assessments/plan-fact-checks/`) and caught actual drift. Throwing it out
  would regress.
- Phase 1's failure mode is over-strictness on forward-references to
  yet-to-exist artifacts (the known `gh-auth-lockdown` churn). Reclassifying
  it to **warn** retains the signal without the false-positive block pain.
- Phase 2 is the new value-add. External deprecations are load-bearing in a
  way that an unanchored path usually isn't: a plan built on a deprecated API
  will fail at implementation time regardless of how clean the prose is.
- Combining both in one agent keeps invocation semantics simple
  (plan-promote calls one gate, one report lands, one exit code).

## D2. Tools: WebSearch, WebFetch, Context7 MCP, Firecrawl MCP.

**Decision:** Orianna's tool list becomes:

```
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebSearch
  - WebFetch
  - mcp__context7__*
  - mcp__firecrawl__*
```

Firecrawl is included in v1 at Duong's direction, reversing the earlier
"defer to v2" stance. The motivating gap: WebFetch's HTML-to-markdown path
returns empty or stubbed markup for JavaScript-rendered docs sites
(single-page-app docs portals, version switchers that hydrate client-side,
vendor marketing pages behind heavy React/Vue shells). Context7 covers the
major indexed libraries; WebFetch covers static HTML/markdown docs;
Firecrawl fills the middle — JS-rendered pages where a naive fetch returns
a shell with no substantive content.

**Rationale per tool:**

- **Context7** (`plugin:context7:context7`) — the MCP server Duong's harness
  already advertises as the correct tool for "current documentation … for a
  library, framework, SDK, API, CLI tool, or cloud service." Returns
  version-pinned docs for the exact library name in the plan. Preferred
  over every other tool for any named library / SDK / framework because
  it's authoritative, structured, and cheap per signal.
- **WebFetch** — read a specific docs URL cited in the plan and check for
  deprecation banners, 404s, redirects to sunset pages. Works well for
  static HTML / server-rendered markdown (MDN, most vendor docs with
  pre-rendered content, RFC-style pages). Cheap, one round-trip.
- **Firecrawl** — the JS-rendered fallback. Use when a cited URL returns
  empty/stubbed markup via WebFetch (SPA docs portals, client-side-
  hydrated version switchers, Next.js app-dir docs with streaming payloads
  that don't render on a plain GET, vendor console pages behind React
  shells). Also the right tool for "is this library's landing page still
  up" checks where the content only exists after hydration. Higher cost
  per call than WebFetch, so never the first choice — only invoked when
  WebFetch explicitly reports thin or empty content (see routing below).
- **WebSearch** — broad freshness discovery ("is X deprecated as of 2026",
  "latest stable version of Y", finding the current canonical URL for a
  rebranded service). Last resort when the claim has no pinned URL and no
  resolvable library name. Cheap per call but noisy; ranked snippets, not
  authoritative docs.
- Read/Glob/Grep/Bash retained for Phase 1.

**Phase 2 routing order (cost + coverage):**

For any B3 claim, Orianna tries tools in this order, stopping at the
first that produces a decisive verdict:

1. **Context7 first** — if the claim references a named library / SDK /
   framework / CLI / cloud service that Context7 indexes. Cheapest per
   signal, highest authority (version-pinned structured docs), and the
   harness recommends it for exactly this case. A clean `@deprecated` or
   "removed in version N" from Context7 short-circuits everything else.
2. **WebFetch second** — if the claim cites a specific URL (or Context7
   resolved the library to a canonical docs URL worth spot-checking). One
   cheap round-trip, good for deprecation banners and sunset redirects on
   static/server-rendered pages.
3. **Firecrawl third** — only when WebFetch returns empty, thin, or
   clearly-stub markup (below a length/selector threshold determined by
   the implementer ADR). This catches JS-rendered docs that WebFetch
   can't read. Higher cost, so gated behind an explicit WebFetch-was-
   insufficient signal rather than run speculatively.
4. **WebSearch last** — discovery only, when the claim has no URL and no
   library Context7 recognizes. Ranked snippets feed back into steps 1–3
   (e.g., search surfaces a canonical URL, then WebFetch or Firecrawl
   reads it). Never the primary verdict source; always a pointer.

Motivation: Context7 is cheap and authoritative, so always first.
WebFetch is cheap and sufficient for the majority of cited URLs, so it
precedes Firecrawl. Firecrawl is precise but expensive, so it's reserved
for the WebFetch-failed subset. WebSearch is cheap but unstructured, so
it only runs when nothing else has a direct path. This ordering
minimizes per-claim cost while maximizing coverage — the expensive tool
runs only when the cheap tools have demonstrably fallen short.

## D3. Claim routing: three buckets, contract-driven.

**Decision:** Extend `agents/orianna/claim-contract.md` (v1 → v2) with a
routing table that classifies every extracted token into exactly one of:

| Bucket | Check path | Example |
|---|---|---|
| **B1 — current-state internal** | Phase 1 grep/ls against repo checkout (existing v1 behavior) | `scripts/plan-promote.sh`, `apps/bee/server.ts` |
| **B2 — forward-ref / planned artifact** | Skip check. Must be marked with "Proposed:", "Will:", "In a future phase:", or sit under an H2/H3 section titled `Proposed`, `Design`, `Plan`, or `Will build` | `apps/newservice/index.ts` (not yet written) |
| **B3 — external reference** | Phase 2 web-verify via Context7 → WebFetch → Firecrawl → WebSearch (in that order of preference; see D2) | Anthropic SDK method names, Firebase CLI flags, Next.js 15 APIs, Figma MCP tool names, vendor docs URLs |

**Classifier rules (in order, first match wins):**

1. If the token matches a speculative marker or sits in a Proposed/Will
   section → B2.
2. If the token is a path-shaped string whose prefix matches the two-repo
   routing table (contract v1 §5) → B1.
3. If the token is a URL (starts with `http`) → B3 (WebFetch).
4. If the token is a bare vendor/library name that appears in a new
   `agents/orianna/external-allowlist.md` with a **version pin** (e.g.
   `firebase-cli >= 13.0`, `@anthropic-ai/sdk >= 0.30`) → B3 (Context7,
   pinned).
5. If the token is a bare vendor/library name **without** a version in the
   plan or in the allowlist → B3 (Context7, unpinned; result severity
   capped at warn — see D5).
6. Otherwise → info finding "unclassified token; add to contract if
   load-bearing."

**Rationale:** The three-bucket split is the essence of the redesign. v1's
biggest false-positive category (forward-refs) gets a first-class B2 bucket
instead of being shoehorned through same-line `<!-- orianna: ok -->`
suppression. The external bucket (B3) is the new capability.

## D4. Invocation: plan-promote (mandatory), plus opt-in pre-commit hint.

**Decision:**

- **Mandatory:** the existing `scripts/plan-promote.sh` gate continues to
  invoke Orianna. Exit-non-zero on any Phase 2 block still halts promotion.
- **Opt-in proactive:** add a new script `scripts/orianna-freshness-check.sh`
  that any planner (Azir, Bard, Neeko) can invoke on their own draft before
  requesting promotion. Not wired to a hook. Not mandatory at plan-write
  time — freshness checks are too expensive to run on every `git commit` in
  `plans/proposed/` (see D7).
- **Retire:** the weekly memory-audit mode stays as-is in v1 of this
  redesign. Adding external checking to memory-audit would blow the token
  budget. Deferred to a follow-up ADR.
- **New:** add a `monthly-external-sweep` mode that re-runs Phase 2 only
  against all plans in `plans/approved/` and `plans/in-progress/`. Catches
  drift that accumulates after promotion (an API that was current when the
  plan passed last month is now deprecated). Runs on a cron / GitHub
  Actions schedule. Output to `assessments/freshness-audits/`.

**Rationale:** Three cadences, three costs. Per-plan-promote is the existing
contract. Per-author-request is cheap (planner-triggered, not blocking).
Monthly is the cheapest way to catch post-promotion drift without running
web checks on every commit.

## D5. Severity thresholds for Phase 2.

**Decision:** Phase 2 findings map to severities as follows.

| Finding type | Default severity |
|---|---|
| Cited docs URL returns 404 / DNS fail | **warn** (one 404 alone ≠ block; link rot is real but not plan-breaking) |
| Cited docs URL redirects to an explicit deprecation/sunset page | **block** |
| Context7 reports the cited method/CLI/flag is marked `@deprecated` in the current published version | **block** |
| Context7 reports the cited method/CLI/flag was **removed** in a version ≤ the version the plan pins (or current latest if no pin) | **block** |
| Library has a major-version bump with breaking changes and plan neither pins a version nor mentions the bump | **warn** |
| Cloud service referenced by name is sunset / merged into another product per official vendor page | **block** |
| Vendor rebrand (old name redirects to new name, same underlying product) | **info** (cosmetic) |
| MCP server tool name change | **warn** if the tool still exists under another name; **block** if removed outright |
| Unpinned library name that Context7 can't resolve (ambiguous) | **warn** capped (see D3.5) |

**Rationale:** A 404 on its own is too noisy to block (link rot happens to
every doc site); a redirect to an explicit sunset page is the strong signal.
Deprecation annotations in the published docs are the highest-precision
signal we can get from Context7 and should block. Breaking version bumps
without plan acknowledgment warn rather than block because they are
sometimes deliberately pinned elsewhere.

## D6. Migration from v1.

**Decision — what carries over:**

- `agents/orianna/profile.md` — updated to describe the two-phase model.
- `agents/orianna/claim-contract.md` — bumped to `contract-version: 2`,
  adds the B1/B2/B3 routing table, adds Phase 2 severity matrix.
- `agents/orianna/learnings/2026-04-19-o4-tdd-stale-seed.md` — retained.
  All Phase 1 discipline is still valuable; it's now a sanity gate not a
  block gate.
- `scripts/orianna-fact-check.sh` — becomes the Phase 1 entry point. No
  behavior change; its exit code is reclassified by the wrapper.
- `scripts/orianna-memory-audit.sh` — unchanged in v1 of this redesign.
- `.claude/agents/orianna.md` — rewritten. Tool list expanded. Role
  description updated. Modes section gains `freshness-check` and
  `monthly-external-sweep`.

**Decision — what retires:**

- Phase 1 **block** severity for categories C1, C2, C6, C7 (contract v1 §4
  "Strict-default rule"). All of these downgrade to **warn** by default in
  contract v2. Rationale: the new primary block surface is Phase 2. Phase 1
  stays as a quality gate, not a promotion gate.
- The Drive-mirror-unpublish happens *after* Phase 2 passes, not after
  Phase 1. Unchanged from v1 ordering in `plan-promote.sh` — fact-check
  gate runs before Drive unpublish (lines 63–86).

**Decision — what's genuinely new:**

- `scripts/orianna-freshness-check.sh` — Phase 2 entry point.
- `agents/orianna/external-allowlist.md` — version-pinned library list
  (D3, rule 4).
- `assessments/freshness-audits/` — new report directory for
  monthly-external-sweep mode.
- Phase 2 severity matrix (D5) added to the contract.

**Carryover of the 200+ days of fact-check discipline:** every existing
`assessments/plan-fact-checks/` report remains valid historical data. The
learnings file (`2026-04-19-o4-tdd-stale-seed.md`) is preserved. The
"grep-style evidence" voice is preserved in the voice / personality section
of `.claude/agents/orianna.md`; it now applies to *external* anchors too
("link + section header" as the reproducible anchor for a docs claim).

## D7. Cost scoping.

**Decision:** hard-limit Phase 2 token cost per plan via four mechanisms.

1. **Scope by extraction.** Only tokens the contract classifies as B3
   trigger web calls. Prose narrative and in-repo paths do not.
2. **Prefer Context7, then WebFetch, then Firecrawl, then WebSearch.**
   Context7 calls are cheaper per signal (structured doc lookup) than a
   generic fetch-and-scan. Routing order per D2: Context7 for named
   libraries → WebFetch for explicit URLs → Firecrawl only when WebFetch
   returned empty/stub markup on a JS-rendered page → WebSearch for
   unresolved bare names. One tool call per claim in the common case;
   Firecrawl is a conditional escalation, not a default.
3. **Per-plan budget cap.** A configurable cap (v1 default: **20 web
   calls per plan**, env var `ORIANNA_FRESHNESS_BUDGET`). The 20-check
   default still holds — the unit remains "one outbound call to any of
   Context7 / WebFetch / Firecrawl / WebSearch," counted uniformly. A
   Firecrawl invocation is one unit, same as a WebFetch, even though
   Firecrawl's underlying cost (both dollars and latency) is higher. The
   budget is a call-count ceiling, not a dollar ceiling — the routing
   order in D2 already keeps the expensive tool rare by gating it behind
   a WebFetch-was-insufficient signal, so the 20-call cap remains the
   right rough-cut limit for v1. Revisit if monthly-sweep telemetry
   shows Firecrawl consuming a disproportionate share of the budget;
   options then include (a) a separate `ORIANNA_FIRECRAWL_BUDGET`
   sub-cap, or (b) weighting Firecrawl calls as 2 units against the
   main budget. Neither is needed on day one. If exceeded, the
   remaining B3 claims are emitted as **warn** findings with the note
   "budget exhausted; verify manually." Promotion is not blocked on
   budget-exhausted warns.
4. **Result cache.** Cache Phase 2 results in
   `assessments/freshness-audits/.cache/<sha256-of-claim>.json` with a
   14-day TTL. A second plan that cites the same SDK method within the TTL
   reuses the cached verdict. Monthly sweep respects the TTL; per-promote
   always honors it.

**Rationale:** Without caps, a single large plan that cites a dozen
Anthropic SDK methods + Firebase CLI flags + Next.js hooks could trigger
30+ web calls × ~2-3 KB each = noticeable token spend on every promote.
The cap + cache reduces amortized cost to near-zero for plans reusing
common libraries and degrades gracefully to warn-not-block when exceeded.

---

# Rejected alternatives

**A. Pure role swap — retire grep-anchor entirely.**
Rejected. Phase 1 has produced real finds in its first day of operation.
The motivating "Firebase GitHub App" bug is internal-drift, not external
drift; a pure external checker would not have caught it. Keeping Phase 1
as a sanity-gate (warn severity) costs almost nothing and keeps that
detection alive.

**B. Two separate agents — Orianna keeps grep-anchor, new agent "Lissandra" does freshness.**
Considered. Rejected for v1 on orchestration cost: two gates in
plan-promote means two invocations, two reports to merge, and harder
severity arbitration when they disagree. The two checks are complementary,
not independent, and a single agent with two modes is the cleaner shape.
Revisit if Phase 2 grows large enough (e.g., dedicated MCP-freshness
checks, dedicated cloud-service-status checks) to warrant a split.

**C. Run Phase 2 on every commit under `plans/proposed/`.**
Rejected on cost (D7). Freshness checks on every draft commit would burn
tokens on unstable WIP prose that hasn't settled. The plan-promote gate is
the right enforcement point; the author-triggered
`orianna-freshness-check.sh` is the right early-warning path for planners
who want feedback before promotion.

**D. Use only WebSearch (no Context7, no WebFetch).**
Rejected. WebSearch returns ranked result snippets, not authoritative
structured docs. Context7 returns version-pinned library docs directly —
the exact signal Phase 2 needs. WebFetch is needed because plans cite
specific URLs that need specific-URL verification, not a search.
Underselling the tool set here would blunt the whole redesign.

**E. ~~Add Firecrawl / generic web crawler in v1.~~ — accepted, see D2.**
Previously rejected on cost and scope grounds. Reversed at Duong's
direction: Firecrawl is now in the v1 tool set as the JS-rendered docs
fallback, gated behind WebFetch-was-insufficient so the higher per-call
cost is only paid when the cheaper path demonstrably fails. Routing
order and budget treatment are specified in D2 and D7.

**F. Make Phase 2 advisory-only (warn, never block).**
Rejected. The whole point of Orianna is a closed-loop gate. Advisory-only
would make Phase 2 equivalent to "a report Duong might read." The severity
matrix (D5) already distinguishes warn from block; that's the right
granularity, not blanket advisory.

**G. Run Phase 2 on memory files too.**
Deferred, not rejected. Memory sweep over hundreds of learnings files
multiplied by per-claim Phase 2 cost would blow the budget immediately. If
the monthly-external-sweep mode proves cheap in practice, revisit in a
follow-up ADR.

**H. Ship a new claim-contract major version (v2) that replaces v1 wholesale.**
Partially accepted. Contract bumps to v2, but the change is additive
(routing table, external allowlist, Phase 2 severity matrix) rather than a
replacement. v1's extraction heuristic, suppression syntax, and two-repo
routing rules all carry forward unchanged.

---

# Open questions (for the implementer ADR, not this one)

- How exactly does Phase 2 authenticate Context7 calls in CI vs locally —
  are any tokens needed, or is the MCP layer enough?
- What is the precise regex/matcher for "deprecated" banners across the
  docs of the top 10 libraries we cite? (The implementer ADR should cite
  each library and confirm the banner format.)
- Does `scripts/orianna-freshness-check.sh` inherit the same cross-repo
  routing as `orianna-fact-check.sh`, or does Phase 2 only look at the
  plan text? (Leaning plan-text only — Phase 1 already handles the
  cross-repo anchors.)
- Do we surface Phase 2 cache hit/miss counts in the report frontmatter
  so the monthly sweep can tell whether cache TTL is too short?
- Who owns `agents/orianna/external-allowlist.md`? Proposal: Lux owns
  library entries, Neeko owns cloud-service entries, a `CODEOWNERS`-style
  header in the file enforces review.

---

# What this ADR is not

- Not a task breakdown. The task ADR (e.g.
  `2026-04-19-orianna-role-redesign-tasks.md`) is the follow-up.
- Not an implementation. Lux is an advisor; Azir or Bard plans the
  tasks; Sonnet specialists execute.
- Not a repeal of `plans/implemented/2026-04-19-orianna-fact-checker.md`.
  That plan stays implemented; this one extends its behavior.
