# PR #32 — missmp/mcps — T13 Option B dormant scaffold (advisory LGTM)

**Date:** 2026-04-24
**Reviewer identity:** senna lane (`strawberry-reviewers-2`) for preflight; posted as comment under `duongntd99` per work-scope protocol
**Commit reviewed:** `2393f20`
**Verdict:** advisory LGTM (dormancy-correct)
**Comment URL:** https://github.com/missmp/mcps/pull/32#issuecomment-4312611246

## What this PR is

Scaffold + runbook for Option B of the self-invite-to-WalletStudio ADR — the API-key-harvest fallback path. Two files, 254 lines total:
- `wallet-studio/src/option-b-fallback.ts` (125 lines) — types + two exported functions that throw a `DORMANT_MESSAGE` referencing ADR §3.2
- `wallet-studio/src/README-OPTION-B.md` (129 lines) — six-section revival runbook

Duong's approval-time amendment: "configured but not filled in — no env, no secrets, structural + documentation only." Every invariant held.

## Independent verification (not trusting Jayce's self-report)

1. `grep -n 'process.env'` — 0 hits
2. `grep -nE '^import \|^from \|require\('` — 0 hits (runtime deps in comments only)
3. Both function bodies are single-line `throw new Error(DORMANT_MESSAGE)`, and the message text names the ADR plus §3.2 plus "fresh Azir ADR" requirement
4. `tsc --noEmit` in a clean clone with `npm install` — exit 0
5. README documents: §3 four gates, §4 seven-step revival, §5 deferred OQs carried forward, §6 file cross-links — break-glass discoverability value prop clearly delivered

## Notable technique

**Belt-and-braces dormancy.** Module isn't imported from `index.ts` or `server.ts` either — even if someone calls an exported function through a hot path, the import has to be added first. Two speed bumps before activation.

## One non-blocking suggestion

Functions typed `Promise<HarvestedApiKey>` but throw synchronously. A `.catch()` chain wouldn't fire — synchronous throw vs rejected promise differ. Harmless for a stub (both paths fail loud), and README §4.1 says REPLACE not unwrap, so future live impl will return a real promise. Flagged as a suggestion only, not a change request.

## Rule 18(a) note

`gh pr checks 32` returns "no checks reported on the branch" — surfaced to Sona for routing. In a dormant doc-only PR this is plausible (nothing to exercise in CI), but if branch protection requires checks, the PR can't merge until they report. If there's no required-check config, that's a repo-config gap separate from this PR.

## Protocol reminders applied

- Preflight via `scripts/reviewer-auth.sh --lane senna gh api user` returned `strawberry-reviewers-2` correctly
- Switched to `duongntd99` for posting; used `gh pr comment` (not `gh pr review`) per work-scope reviewer protocol — Duong approves from `harukainguyen1411`
- Signed `-- reviewer` (neutral) per work-scope anonymity rule — no agent name, no Anthropic reference, no reviewer-handle leak
