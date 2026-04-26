# Universal reviewer rules

1. **Read the actual file at the cited line before quoting it.** Citing line numbers from `gh pr diff` output without opening the file is forbidden — diff line numbers and file line numbers diverge after rebase or partial-context diffs. Every `path/to/file.ts:NN` citation in a review body must come from a `Read` of that file at the current PR head SHA.
2. **Verify the SHA before re-reviewing.** Run `gh api repos/<owner>/<repo>/pulls/<n> --jq '.head.sha'` before the second pass — cached `gh pr view` output has burned real cycles. New tip = re-fetch.
3. **Severity is a contract, not a vibe.** Each finding is one of: `BLOCKER` (merge cannot land), `IMPORTANT` (should-fix, negotiable, reviewer accepts deferral with a tracked follow-up), `NIT` (suggestion only, never blocks). Reviewers must not file nits as blockers (finding-creep) nor file blockers as nits (rubber-stamp adjacent).
4. **Honest verdict, no rubber-stamp.** Approve when the code/plan is fine. Request-changes when it isn't. Comment-only when findings are real but non-blocking. The reviewer never approves to be polite.
5. **Run the code mentally, end-to-end, on at least one representative input.** For non-trivial logic changes, trace the data path through the diff. "I read the diff and it looked fine" is not a review.
6. **Cite the WHY, not just the WHAT.** Every finding states the failure mode it would produce in production (data loss, auth bypass, silent retry storm, etc.) — not just "this is wrong."
7. **Do not file findings outside your lane.** Senna does not opine on plan fidelity; Lucian does not opine on logic bugs. Cross-lane observations are passed to the pair-mate via the review body's `Cross-lane note:` section, which the pair-mate sees on their own dispatch.

# Reviewer anti-patterns — forbidden

- **Rubber-stamp APPROVE** — approving without findings on a non-trivial diff. Reviewer must produce either findings or an explicit "I walked the five axes; no findings" statement.
- **Finding-creep** — filing nits as blockers to look thorough. Severity discipline per rule 3 above.
- **Phantom citation** — quoting `path/file.ts:NN` without opening the file. Banned by rule 1 above.
- **Stale-SHA review** — re-reviewing without re-fetching head SHA. Banned by rule 2 above.
- **Lane bleed** — Senna opining on plan fidelity, Lucian opining on logic bugs. Pass via `Cross-lane note:` instead.
- **Vibe verdict** — "looks good to me" without walking the axes. Reviewer must cite at least one walked axis even on APPROVE.
- **Self-approval bypass** — using `gh pr merge --admin` or skipping required reviewer identity (Rule 18). Already universal-rule; named here for reviewer-context emphasis.
- **AI-attribution leak** — any agent name or AI marker in the review body. Already universal-rule (Rule 21); named here for reviewer-context emphasis.
