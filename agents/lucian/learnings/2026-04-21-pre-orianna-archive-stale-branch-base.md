# 2026-04-21 — PR #14 pre-Orianna archive: stale branch base review technique

## Context

Reviewing PR #14 (`chore/pre-orianna-plan-archive`), a 131-file pure-rename PR
relocating pre-Orianna plans to `plans/pre-orianna/<phase>/`. Branch was cut
from `241bd1c`; main had since gained 3 commits promoting
`s1-s2-service-boundary.md` to `approved/` with fresh Orianna signatures. The
raw PR diff showed an alarming `R099` reverse-move of that plan from
`approved/work/` to `proposed/work/` with the `orianna_signature_approved`
frontmatter field stripped.

## Technique that resolved it

Do not trust the raw PR diff alone when the branch has lagged main. Simulate
the actual merge in a throwaway clone:

```
git clone <repo> /tmp/merge-test
cd /tmp/merge-test
git fetch origin chore/<branch>:pr
git checkout main
git merge --no-ff --no-commit pr
ls -l plans/{approved,proposed}/work/<file>   # final post-merge state
grep "orianna_signature_approved" <file>       # verify signature survives
```

This revealed git's 3-way merge auto-resolves the rename-vs-edit cleanly: the
file stays at `approved/` with the signature intact because main's later
rename-with-edit wins against the branch's reverse-move that touches the same
path. No actual regression.

## Takeaway

When a PR diff appears to revert work that happened on main after branch-cut,
do not block on the diff artifact. Run the merge locally to confirm. Rule 11
(never rebase, always merge) is actually the safer path here — a rebase would
have replayed the reverse-move on top of the new main and clobbered the
signature. The merge strategy's 3-way awareness protects correctness.

## Secondary note — target-path whitelist verification

For PRs that add a new directory under `plans/`, always grep the hook scripts
for their target match lists:
- `scripts/hooks/pre-commit-plan-promote-guard.sh:61,77` — only fires when
  destination is `plans/{approved,in-progress,implemented,archived}/*`.
- `scripts/plan-promote.sh:125–142` — source whitelist.
- `scripts/orianna-sign.sh:103–109` — source whitelist.

A sibling directory outside all three whitelists (like `plans/pre-orianna/`)
is silent by design — no behavior change, no bypass trailer needed.
