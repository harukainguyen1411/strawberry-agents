---
date: 2026-04-19
topic: migration-p2-retarget-repo-refs
session: strawberry-app Phase 2 — repo slug retarget
---

# Learnings: Migration P2 — Repo Slug Retarget (strawberry-app)

## Scratch tree lifecycle

The `/tmp/strawberry-app` scratch tree from the original P2 session was lost (system restart or tmpfs purge). The `/tmp/strawberry-app-review` tree was still present, pointed at the correct remote (`harukainguyen1411/strawberry-app`), and only needed a `git fetch` + `git merge origin/main` to be brought up to date. Always check existing scratch trees in `/tmp/` before cloning fresh.

## Grep sweep findings — most hits are product text, not slug refs

Running `grep -rln 'strawberry'` produces a huge list (60+ files) because "strawberry" is the product name. The actionable scope is much narrower: only slug-form references (`owner/slug`) and URL-form references (`github.com/owner/slug`) matter. The three-grep approach:
1. `grep -rln 'Duongntd/strawberry'` — direct old-slug hits
2. `grep -rln 'harukainguyen1411/strawberry[^-]'` — bare new slug (missing `-app` suffix)
3. `grep -rln 'github.com/Duongntd'` — any URL refs to agent account

## The slug guard regex false-positive bug

`PATTERNS="harukainguyen1411/strawberry|..."` in `check-no-hardcoded-slugs.sh` would match `harukainguyen1411/strawberry-app` because the ERE pattern has no trailing anchor. Fix: `harukainguyen1411/strawberry([^-]|$)`. Test with:
```
echo "harukainguyen1411/strawberry-app" | grep -E "harukainguyen1411/strawberry([^-]|$)"
```
This must return NO_MATCH. `\b` does NOT work here because `-` is not a word-character boundary delimiter in GNU ERE.

## gitleaks allowlist maintenance

When the canonical repo slug changes, the `.gitleaks.toml` regex allowlist needs updating. The new slug `harukainguyen1411/strawberry-app` triggers the generic-api-key heuristic for the same reason the old one did (slash + mixed-case entropy). Add the new slug to `[allowlist].regexes`. Keep the old slug entry — it still appears in sentinel/comment contexts and suppressing it prevents noise.

## Push auth: Duongntd account required for strawberry-app

`gh auth switch -u Duongntd` is required before pushing to `harukainguyen1411/strawberry-app`. The `duongntd99` (personal) account does not have push access. The `harukainguyen1411` account is not in `gh auth` — Duong uses it as a browser-only identity. Agent pushes go through `Duongntd`.

## PR creation: --repo flag required from detached working trees

`gh pr create` fails with "you must first push the current branch to a remote" when the git `remote.pushdefault` or tracking config isn't propagated to the gh CLI context. Fix: always pass `--repo owner/repo --head branch --base main` explicitly.
