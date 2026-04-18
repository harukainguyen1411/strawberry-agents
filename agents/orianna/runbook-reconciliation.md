# Orianna — Audit Reconciliation Runbook

This runbook captures the five-step flow from ADR §4.4 so the first reconciliation
does not require re-reading the ADR.

**Source of truth for Orianna's behavior:** `plans/approved/2026-04-19-orianna-fact-checker.md` §4.4.

---

## Steps

1. **Orianna produces the report.**
   `scripts/orianna-memory-audit.sh` runs the sweep and writes the report to
   `assessments/memory-audits/YYYY-MM-DD-memory-audit.md` with
   `status: needs-reconciliation`. The script commits and pushes the report.

2. **Evelynn reads the report and groups findings by owning agent.**
   Evelynn opens the report, reviews each finding, and groups them by which agent's
   memory or learnings file is affected. She identifies the appropriate fixer for
   each group:
   - **Yuumi** for simple file edits (e.g. updating a stale path, removing a dead
     reference, correcting a SHA).
   - **The owning agent itself** if the finding requires contextual judgment (e.g.
     "was this claim intentionally speculative?" or "does this learning still apply?").

3. **Each delegated agent corrects the memory or learnings file.**
   The fixer receives a task from Evelynn pointing at the specific file and line(s).
   The fixer updates the file (correcting, removing, or marking the claim as
   acknowledged-stale), commits under `chore:`, and reports done to Evelynn.

   > **Acknowledged-stale convention:** if a claim is known-stale but removing it
   > would lose useful historical context, wrap it with a comment:
   > `<!-- acknowledged-stale as of YYYY-MM-DD: <reason> -->`
   > Orianna will not re-flag acknowledged-stale claims in subsequent audits.

4. **Each owning agent reports completion.**
   When all assigned findings in a group are resolved, the fixer confirms to Evelynn.
   Evelynn tracks the reconciliation checklist from the report — each checklist item
   maps to a specific finding.

5. **Evelynn (or Duong) marks the report reconciled.**
   When all items in the `## Reconciliation checklist` section are checked, Evelynn
   (or Duong) edits the report frontmatter:
   - Change `status: needs-reconciliation` → `status: reconciled`
   - Add `reconciled: YYYY-MM-DD` field
   Then commits under `chore:` prefix and pushes.

---

## Frontmatter lifecycle

| Field | Value at creation | Value after reconciliation |
|---|---|---|
| `status` | `needs-reconciliation` | `reconciled` |
| `reconciled` | (absent) | `YYYY-MM-DD` |
| `auditor` | `orianna` | `orianna` (unchanged) |

Only Evelynn or Duong performs the `needs-reconciliation` → `reconciled` transition.
Individual fixers do not update the report frontmatter — they update the memory/learnings
files and report back.

---

## Escalation

If a finding is disputed (the owning agent believes the claim is correct), the owning
agent leaves a comment in the relevant memory/learnings file explaining why, reports
the dispute to Evelynn, and Evelynn makes the final call. Duong is the tiebreaker.

Block-severity findings that remain unresolved after 7 days should be escalated to
Duong directly.
