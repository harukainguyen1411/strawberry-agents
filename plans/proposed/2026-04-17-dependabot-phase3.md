---
status: proposed
owner: camille
date: 2026-04-17
title: Dependabot Phase 3 Addendum — Residual 25 alerts after Phase 1-2 sweep
supersedes: none
addendum-to: plans/approved/2026-04-17-dependabot-remediation.md
---

# Dependabot Remediation — Phase 3 Addendum

Phase 1-2 of `2026-04-17-dependabot-remediation.md` landed successfully: **79 of 104 alerts resolved**. This addendum scopes the remaining **25 alerts** and carries forward the lockfile patterns that worked in Phase 1-2 (per Viktor's and Vi's learnings).

This plan defines **batches, risk, and verification expectations only**. It does **not** assign implementers (per `rule-plan-writers-no-assignment`). Viktor (upgrades), Vi (tests), and Senna + Lucian (review) pick up batches.

---

## 1. Residual Snapshot

| Source | Count | Notes |
|---|---|---|
| Phase 1-2 resolved | 79 | B1, B2, B3, B4a–B4f, B4h, B5, B6, B7, B8, B9 |
| Remaining open | 25 | This plan |
| Original total | 104 | Phase 1-2 baseline |

Regenerate live count before executing any batch here:

```
gh api --paginate "/repos/Duongntd/strawberry/dependabot/alerts?state=open&per_page=100" \
  | jq -r '.[] | [.number, .security_advisory.severity, .dependency.package.name, .dependency.manifest_path, .dependency.scope, (.security_vulnerability.first_patched_version.identifier // "no-fix"), .security_advisory.ghsa_id] | @tsv'
```

Trust live API over UI counts (UI lags). **Critical pre-flight:** re-query before B3b and B3d — a significant share of listed alerts may have auto-closed post-B8 propagation; the verification check in §5 determines what remains in scope.

---

## 2. Inventory of Remaining 25 Alerts

### 2.1 B3a — bee-worker vite/vitest coupled upgrade (2 alerts)

Carried over verbatim from Phase 2 (deferred per risk gate).

| # | Pkg | Manifest | Scope | Fix | GHSA |
|---|---|---|---|---|---|
| 79 | esbuild | `apps/private-apps/bee-worker/package-lock.json` | dev | ≥0.25.0 (via vite 6) | (esbuild CVE series) |
| 81 | vite | `apps/private-apps/bee-worker/package-lock.json` | dev | 6.x | (vite dev-server family) |

**Current state:** bee-worker pins `vite@5.x` + `vitest@2.x`. vitest 2 cannot resolve against vite 6 peer; both must move together. vitest 3 introduces API changes (matcher / config / `vi.mocked` semantics) that may touch test code.

**Pattern applied:** Phase 2 B4g was blocked on this exact coupling. Bee-worker has **no test files** (Vi's learning — `vitest run` exits 1 with "No test files found"), so vitest 3 API breakage has **no blast radius inside bee-worker itself**. The gate is: does the upgraded `vitest` still satisfy peer-range declared elsewhere in the workspace? A `tsc --noEmit` + build is the authoritative green gate.

### 2.2 B3b — root `@tootallnate/once` major bump (1 alert)

| # | Pkg | Manifest | Scope | Fix | GHSA |
|---|---|---|---|---|---|
| 90 | @tootallnate/once | root `package-lock.json` | dev | 3.0.1 | (ReDoS, low) |

**Current state:** root lockfile pins `@tootallnate/once@2.x` via a transitive chain (likely `http-proxy-agent` / `https-proxy-agent` legacy). The same package was bumped cleanly in apps/myapps during B9. Root equivalent requires either (a) root `overrides` entry pinning `@tootallnate/once` to `^3.0.1`, or (b) surgical lockfile patch if full regen would drift too many transitives.

**Pre-flight check:** determine current root-lockfile line count; if it is small enough that a full regen would surface a reviewable diff, prefer regen. If large (>5k lines), use surgical patch per Viktor's myapps pattern.

### 2.3 B3c — myapps `minimatch` multi-major ReDoS series (up to 17 alerts)

| # range | Pkg | Manifest | Scope | Majors present |
|---|---|---|---|---|
| 19, 20, 21, 22, 23 | minimatch | `apps/myapps/package-lock.json` | dev | 3.x chain |
| 25, 26, 27, 28, 29 | minimatch | `apps/myapps/package-lock.json` | dev | 5.x chain |
| 30, 31, 32, 33 | minimatch | `apps/myapps/package-lock.json` | dev | 6.x chain |
| 34, 35 | minimatch | `apps/myapps/package-lock.json` | dev | 10.x chain |

(9.x-major variants were cleared by Phase 1-2; per Camille's own triage learning, 5 distinct majors are usually irreconcilable. Four remain.)

**Current state:** four major version lines coexist because different upstream parents pin different majors. Single-override cannot cover all — npm `overrides` must name the correct first-patched version per major:

- `3.x` → `3.1.2`
- `5.x` → `5.1.7`
- `6.x` → `6.0.1`
- `10.x` → `10.0.1`

These must land as **four separate `overrides[pkg]` entries keyed by parent chain**, not a single unconditional override (that would force majors across boundaries and break parents that require `<=3.x` API).

**Pre-flight check:** confirm per-chain parent packages still pin each major before overriding — if upstream published a new release that reached the fixed version, the override becomes unnecessary (and redundant overrides are pure drift).

### 2.4 B3d — myapps residuals (5 alerts)

| # | Pkg | Manifest | Scope | Fix | GHSA |
|---|---|---|---|---|---|
| 18 | ajv | `apps/myapps/package-lock.json` | dev | ≥6.12.6 / ≥8.x | (proto-pollution) |
| 52 | picomatch | `apps/myapps/package-lock.json` | dev | ≥2.3.1 | (ReDoS) |
| 54 | picomatch | `apps/myapps/package-lock.json` | dev | ≥2.3.1 | (ReDoS) |
| 57 | brace-expansion | `apps/myapps/package-lock.json` | dev | ≥1.1.12 / ≥2.0.2 | (ReDoS) |
| 66 | vite | `apps/myapps/package-lock.json` | dev | 6.x patched | (dev-server family) |

**Verification-before-work requirement (from Vi's learning):** B8 (leaf vite 5→7) propagated into `apps/myapps/package-lock.json`. Alert #66 (vite 6.x series) may already be auto-closed. **Re-query `/dependabot/alerts?state=open` before opening this batch**; if #66 has auto-closed, drop from scope and do not attempt a redundant patch.

---

## 3. Batch Strategy

Phase-1-2 patterns that apply here:

| Pattern | Source | Applies to |
|---|---|---|
| **Surgical lockfile patch** (npm view → paste version/resolved/integrity; `npm ci --ignore-scripts` gate) | Viktor — myapps B4b–B4f | B3b (root, if lockfile large), B3c (all), B3d (all) |
| **Root regen after `overrides`** (delete lockfile, `npm install`, accept drift for small lockfiles) | Viktor — B2/B3/B4g | B3a (bee-worker — small), B3b (root, only if small) |
| **`overrides` per major** for packages whose transitives span major versions | Camille — triage | B3c (minimatch per-major) |
| **Workspace removal during regen** for apps in root `workspaces` | Viktor — B2/B3 | Only if B3a chooses regen path |
| **Workflow dependency audit before touching lockfile** (`cache-dependency-path`, `working-directory`, `hashFiles`) | Viktor | Every batch |
| **`.env.local` copy into worktree for myapps E2E** | Vi | B3c, B3d |
| **Kill port 4173 before E2E** | Vi | B3c, B3d |
| **myapps E2E expected baseline: 29 pass / 7 fail** (visual-regression + navigation:63 pre-existing) | Vi | B3c, B3d — any deviation is a regression signal |

### 3.1 Batches

| Batch | Scope | Contents | Risk | Expected effort |
|---|---|---|---|---|
| **B3a** | `apps/private-apps/bee-worker/package-lock.json` — vite/vitest coupled | vite 5→6 + vitest 2→3 (joint upgrade); regen-small pattern | **Med** — vitest 3 API drift risk, but bee-worker has no test files so blast radius limited to `tsc --noEmit` + build green gate | M |
| **B3b** | root `package-lock.json` — `@tootallnate/once` 2→3 | root `overrides[@tootallnate/once]=^3.0.1`; regen-small if root lockfile is small, surgical otherwise | Low — low-severity ReDoS, dev-scope transitive | S |
| **B3c** | `apps/myapps/package-lock.json` — `minimatch` per-major override | Four `overrides` entries (3.1.2, 5.1.7, 6.0.1, 10.0.1); surgical lockfile patch per Viktor's myapps pattern | Low-Med — long tail, dev-scope, but myapps lockfile discipline demands surgical not regen | M |
| **B3d** | `apps/myapps/package-lock.json` — residuals | ajv, picomatch ×2, brace-expansion, (maybe) vite #66. **Pre-flight: re-query; drop auto-closed alerts.** Surgical patch; one `overrides` block covering all remaining. | Low — all dev-scope, mostly ReDoS. | M |

### 3.2 Phase Ordering

**Phase 3 runs as a single phase** (all four batches can parallelize across separate worktrees per invariant 3). The three myapps batches (B3b cross-reads root; B3c and B3d both touch `apps/myapps/package-lock.json`) MUST serialize with respect to each other — concurrent lockfile edits will merge-conflict. Sequence within myapps: B3c → B3d. B3a and B3b have no shared manifests with the myapps pair and can run fully in parallel.

**Phase 3 Verification.** Re-run `gh api /repos/Duongntd/strawberry/dependabot/alerts?state=open` and confirm count = 0 or every residual is documented as upstream-unpatched.

---

## 4. Known Breaking-Change Risks & Blast Radius

| Package | Concern | Mitigation |
|---|---|---|
| `vite 5→6` (bee-worker) | Config shape changes (`server.warmup`, `build.rollupOptions` key renames), esbuild bundle now 0.25.x. | B3a — Viktor diffs `vite.config.ts` against vite 6 migration guide before writing patch; `tsc --noEmit` + build gate. |
| `vitest 2→3` (bee-worker) | `vi.mocked` generic signature change; `test.each` reporter output; `happy-dom` peer range shift. | B3a — bee-worker has **no test files** per Vi's learning, so vitest 3 API drift does not touch code. If test files are added mid-batch, stop. |
| `@tootallnate/once` major (root) | API: `once()` wrapping changed between 2.x and 3.x (Promise-returning). Only consumed transitively. | B3b — if any first-party code imports directly, stop (it should not; this is a proxy-agent internal). |
| `minimatch` per-major override (myapps) | Applying an override that crosses a parent's declared range will break that parent. | B3c — one override entry per exact major; run `npm ls minimatch` post-patch to confirm no peer-warning. |
| `ajv` (myapps) | ajv 6→8 has JSON Schema draft differences. Transitive only; parents may pin ajv@6. | B3d — prefer pinning to **latest ajv 6.x patched** (6.12.6) rather than crossing to 8.x unless parents allow. |
| `vite #66` (myapps) | Likely auto-closed by B8 propagation. | B3d pre-flight: re-query open alerts before drafting patch. |

**No upgrades here are expected to require source-code changes in strawberry's own code**, with one exception:

1. `vite 5→6` config in `apps/private-apps/bee-worker/vite.config.ts` may need key renames (Viktor confirms at batch start).

---

## 5. Execution Mechanics

Per batch (carries forward §5 from the parent plan):

1. Viktor creates a worktree via `scripts/safe-checkout.sh` — branch `deps/<batch-id>-phase3-<YYYY-MM-DD>`.
2. **Pre-flight (mandatory, all batches):**
   - Re-query `gh api .../dependabot/alerts?state=open` → confirm the alerts in this batch's scope are still open.
   - For any alert that auto-closed post-Phase-2, drop from scope; document in PR.
   - For myapps batches: copy `.env.local` into the worktree (Vi's learning) before any `npm install`.
   - Audit `.github/workflows/` for `cache-dependency-path` / `working-directory` / `hashFiles` references to the target lockfile (Viktor's learning). For myapps, three workflows pin `apps/myapps/package-lock.json` — **never delete the lockfile**.
3. Apply fix per batch's declared pattern (surgical vs. regen-small). For surgical:
   - Source `version`, `resolved`, `integrity` exclusively from `npm view <pkg>@<ver> dist.integrity dist.tarball`.
   - `npm ci --ignore-scripts` after patching — integrity failure = stop.
   - Include raw `npm view` output in PR description as evidence.
   - Explicitly list every field change (field, before, after) in PR description.
4. Run `npm audit --json` before and after; diff in PR.
5. Green gates:
   - **B3a:** `tsc --noEmit` + build. (No test files.)
   - **B3b:** root `npm ci` dry-run + any root-scope script that exercises proxy-agent path (if none, audit diff only).
   - **B3c, B3d:** Vi runs myapps suite. Kill port 4173 first. Expected baseline: vitest 17/17 (post-B8), E2E 29 pass / 7 fail (visual-regression + navigation:63). Any deviation = regression.
6. Senna + Lucian review — Senna focuses on `overrides` correctness, lockfile diff sanity (field-by-field for surgical batches), and code-quality + security; Lucian checks drops-for-auto-closed-alerts align with plan/ADR scope.
7. PR merged with `chore:` prefix (invariant 5).
8. Dependabot alerts auto-close on merge; manually dismiss with "fixed in #PR" if not.

**No `npm audit fix --force`** — silently crosses majors.
**No manual lockfile edits outside the surgical pattern** — every field change must be sourced from `npm view`.
**No rebase** — merge only (invariant 11).

---

## 6. Out of Scope

- CI job to fail builds on new critical/high alerts (separate plan).
- Migration off npm to pnpm (cross-cutting).
- Upgrading Firebase / Google-cloud SDKs to latest major.
- Adding an `overrides` drift check to CI (follow-up, per parent plan §7).
- Any alert that appears after 2026-04-17 — this plan freezes on the 25-alert snapshot.

---

## 7. Success Criteria

- [ ] Open Dependabot alert count = 0, or every residual has a documented reason (upstream unpatched / parent pin blocks).
- [ ] `apps/private-apps/bee-worker` passes `tsc --noEmit` + build on vite 6 / vitest 3.
- [ ] Root `package-lock.json` shows `@tootallnate/once@^3.0.1` resolution and no drift in unrelated packages.
- [ ] `apps/myapps` passes vitest 17/17 and E2E 29-pass baseline post-merge.
- [ ] No regressions in Viktor's or Vi's telemetry over a 48h post-merge window.

---

## Appendix A — Pattern cross-reference

| Phase 1-2 learning | File | Phase 3 batches that apply it |
|---|---|---|
| npm `overrides` only honoured on full regen | Viktor §1 | B3a (if regen path chosen), B3c (on myapps: no — surgical instead) |
| Workspace membership blocks standalone regen | Viktor §2 | B3a (bee-worker is workspace member — check `workspaces` array at batch start) |
| Floating-version drift on full regen | Viktor §3 | B3a (small lockfile, pin drifted packages), B3b (root — only if small) |
| Targeted lockfile surgery (myapps) | Viktor §4 | B3c, B3d (mandatory — full regen blocked by blast radius) |
| Dependabot auto-closure needs manifest to exist | Viktor §5 | All — never delete `apps/myapps/package-lock.json` (3 workflows depend on it) |
| Workflow dependency audit | Viktor §6 | All — pre-flight check §5 step 2 |
| `.env.local` gap in worktrees | Vi §1 | B3c, B3d |
| myapps E2E baseline 29 pass / 7 fail | Vi §2 | B3c, B3d |
| Port 4173 conflicts | Vi §3 | B3c, B3d |
| bee-worker has no test files | Vi §5 | B3a (green-gate = build, not vitest) |

## Appendix B — Live regen commands

```
# Full open-alert snapshot
gh api --paginate "/repos/Duongntd/strawberry/dependabot/alerts?state=open&per_page=100" \
  | jq -r '.[] | [.number, .security_advisory.severity, .dependency.package.name, .dependency.manifest_path] | @tsv' \
  | sort

# Per-manifest count
gh api --paginate "/repos/Duongntd/strawberry/dependabot/alerts?state=open&per_page=100" \
  | jq -r '.[].dependency.manifest_path' | sort | uniq -c | sort -rn

# Confirm a specific alert number is still open
gh api /repos/Duongntd/strawberry/dependabot/alerts/<N> | jq '.state'
```
