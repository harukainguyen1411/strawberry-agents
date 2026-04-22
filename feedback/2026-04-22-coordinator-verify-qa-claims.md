# Coordinator must verify QA claims post-report

**Date:** 2026-04-22
**Reporter:** Sona (self-critique; surfaced by Duong's challenge, twice in one session)
**Severity:** Process discipline — trust-summary failed visibly on PRs #66 and #67
**Scope:** Applies to any coordinator (Sona or Evelynn) relaying a QA subagent's PASS verdict under Rule 16

---

## Observation

In a single session I accepted Akali's PASS summary on PR #66 (dashboard W2)
and then again on PR #67 (demo-preview port) without opening the QA report
file or viewing a single screenshot. Both times Duong caught it with a direct
"did you check the report / did you check the screenshot?" prompt.

On PR #66 I admitted I hadn't; on PR #67 — *same session, same gap* — I did
it again and told Duong "report is legit, good to merge" off the summary
alone. He had to ask a second time: "did you check akali report or did you
just trust her."

Akali's reports happened to be accurate on verification, which is the worst
possible reinforcement: the trust shortcut pays off until the one time it
doesn't, and by then a bad surface has shipped.

## Why the summary alone isn't enough

1. **Final-message visibility rule.** I see only the subagent's closing
   narrative. Every tool call, every screenshot inspection, every pixel
   comparison the subagent actually performed is invisible to me. The
   narrative is her *interpretation* of her own work, not the artifact.
2. **Artifacts are ground truth.** For a visual surface, the screenshot *is*
   the acceptance criterion. A sentence saying "brand Aviva rendered" is a
   secondhand claim; the PNG with `#B60000` in it is the first-hand evidence.
3. **My value as coordinator is holding the outcome.** If Duong wanted the
   summary relayed unverified, he could read Akali's task output himself.
   The coordinator's job is to reconcile summary against artifact and only
   then speak.

## Rule I should follow

After any QA subagent returns PASS on a Rule 16 surface, before I tell Duong
"ready to merge" I must have used the Read tool on:

1. The QA report file (end-to-end, not just the PASS/FAIL table)
2. At least one screenshot for each distinct surface / state claimed

And reconciled body narrative against table outcomes — e.g. if the table says
12/12 PASS but the body describes an observation that sounds like a failure,
resolve it before relaying.

## Cost to do it vs cost of skipping

- **Doing it:** ~2 minutes of wall-clock reading one markdown file and
  1–2 PNGs. Cheap.
- **Skipping it:** credibility hit the first time Duong has to ask, and a
  merged bad surface the first time Akali is wrong. Neither has happened on
  outcome yet, but process-wise the skip already failed twice this session.

## Structural proposal

Add to `agents/sona/CLAUDE.md` (and Evelynn's) a Rule 16-adjacent obligation:

> **Coordinator QA verification:** After a QA subagent reports PASS on a
> Rule 16 surface, the coordinator must Read the QA report file and ≥1
> screenshot referenced therein before relaying "ready to merge" to Duong.
> Trust-summary is not sufficient.

This is a coordinator-side companion to Rule 16 (which binds the QA agent).
Rule 16 ensures the evidence exists; the companion ensures the coordinator
actually looks at it.

## Related failure modes to watch

- Reviewer agents (Senna/Lucian) also return verdict summaries. For those I
  routinely link to the verdict file in PR comments, so Duong sees them
  directly. But I should at least skim the verdict file myself before
  pronouncing the PR merge-ready — same failure mode, lower blast radius
  (text findings vs visual acceptance).
- Ekko audit reports: similar. If Ekko claims "no callers" of X, I should
  spot-check one grep rather than relay the conclusion.

## Action items

- [ ] Amend `agents/sona/CLAUDE.md` with the coordinator-QA-verification rule.
- [ ] Amend `agents/evelynn/CLAUDE.md` symmetrically.
- [ ] Add this to Sona learnings index under 2026-04-22.
