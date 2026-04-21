# 2026-04-21 — Orianna work-concern routing review (PR #7)

## PR
`orianna-work-repo-routing` — harukainguyen1411/strawberry-agents#7. Author: duongntd99 (Talon).

Adds `concern: work` → `WORK_CONCERN_REPO` routing to `scripts/fact-check-plan.sh` and parallel docs in the Orianna prompt + claim contract.

## Findings

### Concern parser robustness — all edge cases default-safe
The awk parser (fact-check-plan.sh:80–91) strips `concern: ` prefix + surrounding whitespace, then the bash uses strict `= "work"` equality. Walked through:

- Case variants (`Work`, `WORK`) → fail compare → default-safe.
- YAML-quoted values (`"work"`, `'work'`) → quotes preserved in val → fail compare → default-safe.
- Inline YAML comments (`concern: work # note`) → fail compare → default-safe.
- Missing / truncated frontmatter, multiple concern lines → handled via `count == 1` guard + `exit`.

**No injection surface** — `PLAN_CONCERN` is only used in string equality. Crafted values (backticks, `$(...)`, semicolons) cannot execute; they just fall through to the default route.

Pattern to remember: when the code uses **exact equality** against a constant, the "unknown value" path is inherently default-safe. Only worry about injection when the variable flows into `eval`, command substitution, or file paths.

### Prompt ↔ script parity methodology
For two-path gates (LLM primary + bash fallback), verify parity by enumerating the concrete cases the user cares about ("what if plan has X") and tracing BOTH paths. Here:

| Case | Prompt says | Script does |
|------|-------------|-------------|
| `concern: work` | route to work-concern | route to work-concern |
| `concern: personal` | route to strawberry-app | route to strawberry-app |
| no `concern:` | route to strawberry-app | route to strawberry-app |
| other value | route to strawberry-app | route to strawberry-app |

Diverging cases become review findings. In this PR, they matched exactly.

Note: a pre-existing asymmetry (not from this PR) — the prompt calls for `git fetch origin main` before checking, the bash doesn't. Noted for context but not in-scope.

### CI paths-filter trap (out of scope but flagged)
PR also bundled `ops: add paths filter to ci.yml and preview.yml`. Not my lane but worth noting: adding `paths:` filter means branches that don't touch `apps/**` never run required checks, which interacts with branch protection (required checks would stay pending forever, blocking merge). Flagged in review for Lucian / Orianna.

### Test hardening opportunities (non-blocking)
- Quoted-YAML-value test would lock silent-default behavior as an explicit invariant.
- Explicit `dashboards/` and `.github/workflows/` routing tests — cheap belt-and-suspenders.
- `trap` in test helper would prevent report-dir litter on test failure.

## Verdict
APPROVED. Posted via `scripts/reviewer-auth.sh --lane senna`. Review landed as `strawberry-reviewers-2` with state APPROVED.

CI is 11-red due to Actions billing block (recurring environmental, not code) — Rule 18 still blocks merge until billing is restored.
