# PR missmp/company-os#67 — preview-iframe-staleness-triage fidelity

**Plan:** `plans/in-progress/work/2026-04-22-preview-iframe-staleness-triage.md` (Karma, Orianna-signed v2).
**Verdict:** APPROVE fidelity. Posted as `gh pr comment` under `duongntd99` — work-repo bot-access gap remains (reviewer-auth.sh returns 404 on missmp/company-os). Comment URL: https://github.com/missmp/company-os/pull/67#issuecomment-4295646725

## What went right

- Textbook T1..T4 commit chain: xfail → port+delete → additive feat → fix+flip. Rule 12 ordering verified via `.parents[].sha` = T1 commit sha.
- Four studio.js `/v1/preview/` → `/preview/` replacements match api-repo canonical `/preview/{session_id}` spec.
- deploy.sh branch guard is verbatim Ekko Option B (git rev-parse check, exits 1).
- requirements.txt cleanly drops fastapi/uvicorn/requests — no FastAPI residue.
- T3 is truly additive — only `server.py` touched; fullview handler + CORS only.

## Reusable techniques

- **Rule 12 parent-SHA verification:** `gh api repos/.../commits/<impl-sha> --jq '.parents[].sha'` compared against T1 sha is the single highest-signal check for xfail-first ordering. Cheaper than fetching full patches.
- **Textbook T1..Tn plan → PR commit mapping:** when a plan declares `T1 test → T2..Tn impl → Tn flip`, the fidelity review collapses to (a) commit-count = task-count, (b) first commit adds xfail, (c) last commit removes xfail, (d) intermediate commits are scoped to plan task boundaries. Karma's plan for this PR was almost machine-checkable.
- **Plan-path prefix cosmetic drift:** when a Sona-delegated plan writes paths as `mmp/workspace/tools/...` but the PR lands at `tools/...`, that's workspace-root vs repo-root framing, not structural divergence. Call out as plan hygiene note for future Karma plans.

## Work-repo gap still active

`strawberry-reviewers` has no collaborator access on `missmp/company-os`. Fallback is plain `gh pr comment` under duongntd99 (allowed on self-authored PRs; `--approve` still structurally blocked). Preflight `scripts/reviewer-auth.sh gh api repos/missmp/company-os` before drafting. Sona previously flagged for bot access grant.

## Unrelated tool issue spotted

`scripts/reviewer-auth.sh` from cwd `/tmp` produced `decrypt.sh: refusing target outside /Users/.../secrets: /reviewer-auth.env` — looks like a path-resolution issue when reviewer-auth.sh is invoked from outside the strawberry-agents repo root. Not blocking this review (preflight confirmed no access anyway), but worth a follow-up plan if it recurs.
