# 2026-04-19 — apps-restructure ADR, post-resolution audit + revision

## Session

Duong answered the 10 gating questions + 6 removal confirmations on
`plans/proposed/2026-04-19-apps-restructure-darkstrawberry-layout.md`.
Task: fold answers in, audit unknowns, resolve Q3/Q7/Q10 by architect
decision, leave plan in `proposed/` for Duong's review.

## Audit findings (via `gh api .../git/trees/main?recursive=1`)

- **`apps/platform/`** — not scratch, not a shared lib. It is the
  **darkstrawberry launcher shell** in progress: `main.ts`, `App.vue`,
  `router/index.ts`, `registry/appRegistry.ts`, `registry/firestoreRegistry.ts`,
  `core/appLoader.ts`, `firebase/platformFirestore.ts` (11.8 KB), full
  `views/` (Home, Settings, YourApps, AppSuggestions, AccessDenied, NotFound),
  and rich `components/` tree (access/collaboration/fork/icons/layout/ui).
  Has no `package.json`, no `vite.config.ts`, no `index.html`, no
  `tsconfig.json`. Architect call: **keep in place.** Promotion to
  `apps/darkstrawberry-apps/` is a separate concern once it grows a real
  workspace config.
- **`apps/shared/`** — live. `firebase/appFirestore.ts` + `index.ts`,
  `types/AppManifest.ts`, `ui/icons/`. Consumed by `apps/myapps` via
  `@shared` Vite alias (`../../shared`).
- **`dashboards/dashboard/`** — only `.gitkeep`. Empty placeholder. Safe
  delete.
- **`dashboards/shared/`** — only `.gitkeep`. Safe delete.

## Architect decisions

- **Q1 (subdomain vs single-host)** — Duong chose single host, which
  descopes the original Phase 4 "Firebase multi-site split." Phase 4 is
  re-purposed as "composite build wiring" and merged with Phase 3 (per Q8)
  for deploy-integrity.
- **Q7 (tsconfig.base.json)** — do **not** create one. Every package has a
  working tsconfig. Adding a base tsconfig is a separate concern
  (path-alias unification). Karpathy "surgical changes" — don't mix
  unrelated architecture into a mechanical restructure.
- **Q10 (release-please cutover)** — repo state surprised me:
  `release-please-config.json` enrolls **only** `dashboards`; no other
  package is version-tracked. Manifest is `{"dashboards": "0.1.0"}`. Solution
  is trivial: re-key the config map key and the manifest key from
  `dashboards` → `apps/dashboards` in the same PR as the move. Version
  preserved at `0.1.0`. No reset.

## Things I want to remember

1. Always audit before removing a directory with no `package.json` — the
   absence of a package.json doesn't mean scratch. `apps/platform/` is
   real code that just hasn't been wired as a workspace yet.
2. `gh api .../git/trees/main?recursive=1` is the fastest way to get the
   full repo tree for auditing — beats drilling via per-directory
   `gh api contents` calls for large scans.
3. release-please is keyed on the **config map key path**, not on tag
   history — so a directory move + key rewrite in the same PR preserves
   version memory cleanly.
4. When Duong chooses single-host client-routed, a whole category of
   migration complexity (multi-site targets, DNS, `.firebaserc` targets
   blocks) vanishes. Always ask the routing question first — it sets the
   ceiling on Phase 4 scope.

## Follow-ups for next agent

- Kayn/Aphelios should break Phase 3+4 into a **single** task list, not two.
- `apps/platform/` wiring as a proper workspace (package.json + vite
  config + hosting) deserves its own follow-up plan once the restructure
  lands. Call it out in the approved-plans queue.
- Composite-build integration between `apps/darkstrawberry-apps/` top-level
  Vite config and `apps/platform/`'s registry/appLoader is the technical
  risk in Phase 3+4 — call this out in the task list.
