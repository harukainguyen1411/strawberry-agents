# Lissandra — Learnings Index

- 2026-04-04-glob-count-id-antipattern.md — Generating IDs by counting existing files is a race condition; use timestamp + random hex instead | last_used: 2026-04-04
- 2026-04-13-secondary-sa-consumers.md — "Delete local SA" PRs must account for GCE workers and other secondary consumers; grep .env.example and provisioning scripts | last_used: 2026-04-13
- 2026-04-14-callable-fn-storage-path-traversal.md — Firebase callable fn: validate client-supplied storage paths against uid-scoped prefix before bucket.file() | last_used: 2026-04-14
