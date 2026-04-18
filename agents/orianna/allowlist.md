# Orianna Allowlist — v1

> **Adding entries is a PR-review decision. Removing entries requires a plan.**

This file enumerates known-good names that Orianna passes without requiring an
explicit anchor. It is seeded with common vendor names and platform primitives
that appear frequently in plans and whose legitimacy is not in question. The
list grows over time as patterns are learned; entries are never removed without
a plan justifying the removal.

---

## Section 1 — Vendor bare names (allowed without anchor)

These names refer to well-known vendor products or platforms. When they appear
as bare names in a plan (not combined with a specific integration specifier),
Orianna passes them without requiring a file/line anchor.

- Firebase
- GCP
- Google Cloud Platform
- Cloud Run
- Cloud Build
- Cloud Storage
- Artifact Registry
- Secret Manager
- GitHub
- GitHub Actions
- Dependabot
- Cloudflare
- Cloudflare Workers
- Cloudflare Pages
- PostgreSQL
- Supabase
- Node.js
- TypeScript
- npm
- pnpm
- Vite
- Vitest
- Playwright
- Docker
- Terraform
- age
- age-encryption
- Discord
- Telegram
- Slack
- Hetzner
- GCE
- Vertex AI
- ccusage
- Chart.js
- Trading212
- T212
- Interactive Brokers
- IB
- vue-virtual-scroller

---

## Section 2 — Specific integrations requiring anchors (never allowlisted as bare names)

These are compound names that reference a specific configured integration —
not just a vendor product. They must always be anchored to a file, a `gh api`
call result, or an official docs link confirming the integration is actually
wired up.

- Firebase GitHub App
- Firebase CI/CD GitHub App
- GitHub App (any named GitHub App instance — always requires anchor)
- Firebase Hosting GitHub Action
- Cloud Run service names (e.g. `bee-worker`, `discord-relay` — any named
  service, not the platform itself)
- Named GitHub Actions secrets (e.g. `FIREBASE_SERVICE_ACCOUNT`,
  `GCP_SA_KEY` — must be anchored to the workflow file that consumes them)
- Named Cloudflare Workers routes or zones
- Named Supabase projects or connection strings
- Named Cloud Storage buckets
- Named Artifact Registry repositories

---

## Usage notes

- The distinction between Section 1 and Section 2 is specificity: "Firebase"
  is a vendor; "Firebase GitHub App" is a specific integration that must be
  proven to exist.
- Shell builtins and POSIX utilities (`ls`, `grep`, `git`, `bash`, `test`,
  `cd`, `mkdir`, `rm`, `cat`, `echo`, `set`, `export`, `command`) are always
  allowlisted implicitly and do not need entries here.
- Standard CLI tools documented in the repo (`gh`, `claude`, `age`, `npm`,
  `pnpm`, `node`, `jq`) are implicitly allowlisted as tool names; only their
  specific flag combinations or invocation paths require verification.
- To add an entry to Section 1: open a PR, add the line, and note in the PR
  description why the name is vendor-generic rather than integration-specific.
- To remove any entry: a plan is required, with rationale explaining why the
  name should no longer pass without an anchor.
