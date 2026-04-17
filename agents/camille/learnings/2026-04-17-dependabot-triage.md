# Dependabot triage — field notes

**Context:** 2026-04-17, triaged 104 open alerts on Duongntd/strawberry.

## Key lessons

1. **`gh api /repos/<o>/<r>/dependabot/alerts` does NOT support `?page=` pagination** — returns HTTP 400. Use `gh api --paginate` instead, which uses cursor pagination internally.

2. **UI counts can lag reality.** Duong's team-lead said "96 vulnerabilities" (from the UI); live API returned 104. Push response from GitHub also reported 104. Always trust the live API over UI-quoted counts.

3. **Concentration matters.** In this repo, 71% of alerts (74/104) lived in a single `apps/myapps/package-lock.json`. Before designing batches, always compute per-manifest distribution — most "horrifying" alert totals collapse to 2-3 hot manifests.

4. **Transitive-fix strategy:** for transitive criticals that `npm audit fix` won't reach (common with bundled SDK deps like Google-cloud's `undici`/`protobufjs`), use `overrides` in `package.json`. Avoid `npm audit fix --force` — silently crosses majors.

5. **`minimatch` alerts across 5 major versions (3/5/6/9/10) are usually irreconcilable.** Parent packages pin old majors. Accept residue or add one `overrides` entry per major.

6. **Remote push status:** reports of "push broken" should be verified, not assumed. Push worked fine this session despite prior session close claim.

7. **Plan structure for security batches:** size each batch to a single manifest OR a single package family. Never mix, because a breaking bump in one family will otherwise block unrelated patches in the same batch.
