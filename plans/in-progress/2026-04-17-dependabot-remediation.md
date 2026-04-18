---
status: in-progress
owner: camille
date: 2026-04-17
title: Dependabot Vulnerability Remediation — 104 open alerts across monorepo
---

# Dependabot Vulnerability Remediation

Triage and fix all open Dependabot alerts on `Duongntd/strawberry`. Snapshot taken 2026-04-17 via `gh api /repos/Duongntd/strawberry/dependabot/alerts`.

This plan defines **batches, phase ordering, risk calls, and verification expectations**. It does **not** assign implementers — Viktor (upgrades), Vi (tests), and Jhin (review) pick up batches per `rule-plan-writers-no-assignment`.

---

## 1. Snapshot

| Severity | Count |
|---|---|
| critical | 5 |
| high | 42 |
| medium | 49 |
| low | 8 |
| **Total open** | **104** |

(Dependabot UI reported 96; live API returns 104. Treat 104 as canonical.)

**By scope:** 23 runtime, 78 development, 3 unknown.
**By ecosystem:** 100% npm. No Go, Python, or Actions alerts.
**By manifest concentration:**

| Manifest | Alerts |
|---|---|
| `apps/myapps/package-lock.json` | 74 |
| `package-lock.json` (root) | 14 |
| `apps/private-apps/bee-worker/package-lock.json` | 4 |
| `apps/functions/package-lock.json` | 2 |
| `apps/discord-relay/package-lock.json` | 2 |
| `apps/deploy-webhook/package-lock.json` | 2 |
| `apps/coder-worker/package-lock.json` | 2 |
| `apps/myapps/{portfolio,read,task}-tracker/package.json` | 3 |
| `apps/yourApps/bee/package.json` | 1 |
| `apps/myapps/task-list/package.json` | 1 |

**71% of alerts live in `apps/myapps/package-lock.json`**. A single clean lockfile regeneration there clears most of the noise.

**Direct vs. transitive:** All but 4 alerts are transitive. The 4 direct vulns are all `vite@6.4.2` in leaf app `package.json` files (portfolio-tracker, read-tracker, task-list, yourApps/bee).

---

## 2. Full Inventory

Columns: alert#, severity, package, manifest, scope, first-patched-version, GHSA.

### 2.1 Critical (5)

| # | Pkg | Manifest | Scope | Fix | GHSA |
|---|---|---|---|---|---|
| 104 | protobufjs | root `package-lock.json` | runtime | 7.5.5 | [xq3m-2v4x-88gg](https://github.com/advisories/GHSA-xq3m-2v4x-88gg) |
| 103 | protobufjs | `apps/private-apps/bee-worker/package-lock.json` | runtime | 7.5.5 | xq3m-2v4x-88gg |
| 102 | protobufjs | `apps/functions/package-lock.json` | runtime | 7.5.5 | xq3m-2v4x-88gg |
| 101 | protobufjs | `apps/myapps/package-lock.json` | runtime | 7.5.5 | xq3m-2v4x-88gg |
| 24  | basic-ftp | `apps/myapps/package-lock.json` | development | 5.2.0 | [5rq4-664w-9x2c](https://github.com/advisories/GHSA-5rq4-664w-9x2c) |

### 2.2 High — runtime (6)

All are `undici` prototype-pollution / SSRF / CRLF family, pulled in via Firebase/Google-cloud SDKs.

| # | Pkg | Manifest | Fix | GHSA |
|---|---|---|---|---|
| 46, 48, 49 | undici | `apps/myapps/package-lock.json` | 6.24.0 | f269/v9p9/vrm6 |
| 92, 94, 95 | undici | root `package-lock.json` | 6.24.0 | f269/v9p9/vrm6 |

### 2.3 High — development (36)

Dominated by `minimatch`, `tar`, `picomatch`, `basic-ftp`, `flatted`, `hono`, `@isaacs/brace-expansion`, `@modelcontextprotocol/sdk`, `rollup`, `vite`, `path-to-regexp`, `lodash`, `@hono/node-server`. See Appendix A for the full per-alert list.

### 2.4 Medium (49)

Breakdown: `hono` (12), `vite` (11), `undici` (8), `esbuild` (6), `hono/node-server` (1), `ajv` (2), `brace-expansion` (2), `lodash` (1), `path-to-regexp` (1), `picomatch` (2), `yaml` (1), `@hono/node-server` (1), `vite` direct in 4 leaf `package.json` files.

### 2.5 Low (8)

`@tootallnate/once` (4), `undici` (2), `hono` (1), `qs` (1). All low-severity path traversal / ReDoS bumps.

Full per-alert TSV preserved at `/tmp/alerts.tsv` during session; regenerate via:

```
gh api --paginate "/repos/Duongntd/strawberry/dependabot/alerts?state=open&per_page=100" \
  | jq -r '.[] | [.number, .security_advisory.severity, .dependency.package.name, .dependency.manifest_path, .dependency.scope, (.security_vulnerability.first_patched_version.identifier // "no-fix"), .security_advisory.ghsa_id] | @tsv'
```

---

## 3. Batch Strategy

**Design goals:**

- Keep each batch scoped to one manifest **or** one package family so a breaking bump doesn't block unrelated work.
- Parallelizable: Viktor can run 3-4 batches concurrently in separate worktrees.
- `npm audit fix` (non-force) is preferred over manual edits where it lands on the patched version cleanly. Manual `npm install <pkg>@<ver>` only where audit-fix is blocked by peer constraints.
- Each batch ends at a clean lockfile + green test run + a single PR.

### 3.1 Batches

| Batch | Scope | Contents | Risk | Expected effort |
|---|---|---|---|---|
| **B1** | root `package-lock.json` runtime critical/high | protobufjs → 7.5.5; undici → ≥6.24.0 | Low — all transitive, forced resolution via `overrides` if audit fix doesn't reach | S |
| **B2** | `apps/functions/package-lock.json` | protobufjs → 7.5.5; @tootallnate/once → 3.0.1 (low, bundle) | Low — Cloud Functions runtime; smoke-test cold start | S |
| **B3** | `apps/private-apps/bee-worker/package-lock.json` | protobufjs → 7.5.5; @tootallnate/once (**vite + esbuild split to B4g**) | Low | S |
| **B4g** | `apps/private-apps/bee-worker/package-lock.json` — vite/vitest upgrade | vite 5→6.4.2 + vitest 2→3.x (code-change-required: vitest 3 has API changes) | **High** — requires vitest config/matcher review; Viktor stops and pings team-lead if test breakage found | M-L |
| **B4a** | `apps/myapps/package-lock.json` — runtime criticals | protobufjs → 7.5.5; undici → ≥6.24.0 | Low | S |
| **B4b** | `apps/myapps/package-lock.json` — `hono` family | hono + @hono/node-server bumps to latest patched. **Resolved out-of-band 2026-04-18** — hono@4.12.14 / @hono/node-server@1.19.14 already on main, all hono-family alerts state=fixed. | **Med-High** — hono has minor version churn; possible route/middleware API drift. Needs Vi to run full app test suite. | M |
| **B4c** | `apps/myapps/package-lock.json` — `vite`+`rollup`+`esbuild` build toolchain | vite → patched, rollup → patched, esbuild → 0.25.0 | **Med** — build toolchain bump; watch for plugin compat. Dev-only, so runtime blast radius is zero. | M |
| **B4d** | `apps/myapps/package-lock.json` — `minimatch`+`picomatch`+`brace-expansion`+`@isaacs/brace-expansion` | Glob family — mostly transitive bumps via overrides | Low | S |
| **B4e** | `apps/myapps/package-lock.json` — `tar` family | tar → patched (7.5.x series has 4 alerts) | Low — all transitive | S |
| **B4f** | `apps/myapps/package-lock.json` — residual | basic-ftp (critical dev + high dev), @modelcontextprotocol/sdk, flatted, path-to-regexp, lodash, ajv, yaml, qs, @tootallnate/once | Low-Med — long tail, mostly dev. @modelcontextprotocol/sdk may have API drift. | M |
| **B5** | `apps/discord-relay/package-lock.json` | esbuild 0.25.0, vite 6.4.2 | Low | S |
| **B6** | `apps/deploy-webhook/package-lock.json` | esbuild 0.25.0, vite 6.4.2 | Low | S |
| **B7** | `apps/coder-worker/package-lock.json` | esbuild 0.25.0, vite 6.4.2 | Low | S |
| **B8** | Leaf `package.json` direct vite bumps | `apps/myapps/portfolio-tracker`, `read-tracker`, `task-list`, `apps/yourApps/bee` — vite 6.4.2 → patched | **Med** — direct major/minor bump in 4 frontends; run each app's dev server + build | M |

### 3.2 Phase Ordering

Phases run sequentially; batches inside a phase run in parallel.

**Phase 1 — Critical & High runtime (ship within 24h of plan approval).**
B1, B2, B3, B4a. Four parallel worktrees. Blocks all other work on same manifest.

**Phase 2 — High dev + Med runtime.**
B4b (hono), B4c (build toolchain), B4e (tar), B4g (bee-worker vite/vitest). B4b is the riskiest; Vi runs the full `apps/myapps` E2E suite. B4g requires code-change review before execution.

**Phase 3 — Medium & Low cleanup.**
B4d, B4f, B5, B6, B7, B8. Parallel; low aggregate risk.

**Phase 4 — Verification.**
Re-run `gh api /repos/Duongntd/strawberry/dependabot/alerts?state=open` and confirm count = 0 (or only alerts awaiting upstream patches).

---

## 4. Known Breaking-Change Risks

| Package | Concern | Mitigation |
|---|---|---|
| `hono` | Minor versions have introduced middleware signature changes; patched version may cross a minor boundary. | B4b runs Vi's full route test suite; if breakage, pin `hono` in `overrides` and file a follow-up plan. |
| `vite` (direct, 4 leaf apps) | Patched vite may be a minor bump; plugin compat risk (react, vue). | B8 requires full `npm run build` + `npm run dev` smoke per app. |
| `rollup` / `esbuild` | Build toolchain; transitive via vite. | B4c / B5-B7 — confirm build output byte-for-byte against prior commit where feasible; at minimum, green build. |
| `@modelcontextprotocol/sdk` | 0.x-series SDK; API stability unknown. Dev-only (used by MCP tooling). | B4f — Viktor inspects MCP call sites; if major bump, isolate into its own PR. |
| `protobufjs` | Transitive via Google SDKs. Must use `overrides` in root and each app's `package.json` to force 7.5.5 if transitive resolution won't land it. | Standard npm `overrides` pattern. |
| `undici` | Same — force via `overrides` if audit fix won't bump it. Undici ships with Node 18+ but Firebase/Google SDKs bundle their own. | `overrides` entry per manifest. |
| `minimatch` major versions | 3.x / 5.x / 6.x / 9.x / 10.x all present → likely not reconcilable to a single version; each transitive chain needs its own `overrides` entry. | B4d: one override per major. Accept residue if parent packages pin old majors. |

**No upgrades here are expected to require source-code changes in strawberry's own code**, with three exceptions:

1. `@modelcontextprotocol/sdk` — only if major version bump.
2. `hono` — only if a middleware signature changed in the app's own route handlers.
3. `vite` direct in 4 leaf apps — only if a config option was renamed.

All three are flagged for Viktor to confirm at batch start before proceeding.

---

## 5. Execution Mechanics

Per batch:

1. Viktor creates a worktree via `scripts/safe-checkout.sh` — branch name `deps/<batch-id>-<YYYY-MM-DD>`.
2. In the worktree, at the target manifest directory:
   - Run `npm audit --json > /tmp/audit-before.json`.
   - Apply fixes: `npm audit fix` (no `--force`), or explicit `npm install <pkg>@<ver>`, or add `overrides` to `package.json` for transitives.
   - Run `npm audit --json > /tmp/audit-after.json` and diff.
   - Run the app's local test suite + typecheck + build.
3. Vi runs the batch's owning app(s) E2E / smoke. For B4b (hono) and B8 (vite frontends), full suite mandatory.
4. Jhin reviews the PR — focuses on `overrides` correctness and lockfile diff sanity, not full lockfile line-by-line.
5. PR merged with `chore:` prefix per invariant 5.
6. Dependabot alert(s) auto-close on merge; if not, manually dismiss with "fixed in #PR".

**No `npm audit fix --force`** — will silently cross major versions.
**No manual lockfile edits** — regenerate via `npm install`.

---

## 6. Out of Scope

- Adding a CI job to fail builds on new critical/high alerts. (Separate plan — site-trust-hardening adjacent.)
- Migrating from npm to pnpm to deduplicate lockfiles. (Cross-cutting; don't combine.)
- Upgrading Firebase / Google-cloud SDKs to the latest major. (Out of scope; we only bump transitives.)
- Signed commits / commit-signing policy. (Separate.)
- Repo-wide secret rotation (nothing in the alert set indicates credential exposure).

---

## 7. Success Criteria

- [ ] Open Dependabot alert count = 0, or every residual alert has a documented reason (e.g. upstream unpatched).
- [ ] All 10 distinct manifests pass `npm audit --production` with no high/critical.
- [ ] `npm run build` + `npm test` green on `apps/myapps`, `apps/functions`, `apps/private-apps/bee-worker`, `apps/discord-relay`, `apps/deploy-webhook`, `apps/coder-worker`, and the 4 leaf tracker apps.
- [ ] No regressions in Viktor's or Vi's observable telemetry over 48h post-merge window.
- [ ] Post-merge: Shen adds `overrides` drift check to CI (follow-up plan, not this one).

---

## Appendix A — Per-alert manifest (high severity, development)

See `/tmp/inv-sorted.tsv` during the authoring session, or regenerate with the `gh api` command in §2. Alert numbers: 11, 12, 13, 15, 19–23, 25, 26–30, 31–35, 36, 39, 41, 42, 44, 50, 52, 53, 58, 59, 62, 63, 64, 75, 99, 100.

## Appendix B — Operational notes

- **Push reliability:** last session reported strawberry's remote push as broken. If `git push` fails, stop and flag to Evelynn — do not attempt forced or alternative-remote pushes.
- **Worktree hygiene:** per invariant 3, never `git checkout` directly; each batch = one worktree. Invariant 1 (no uncommitted work) means batches commit-as-they-go.
- **Turborepo cache:** after lockfile changes, run `turbo run build --force` at least once to bust stale caches before declaring green.
