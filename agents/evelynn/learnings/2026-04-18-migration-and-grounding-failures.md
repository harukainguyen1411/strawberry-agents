# 2026-04-18 — Migration session + grounding failures

## Plans must ground integration claims empirically

Three plan claims failed this session because the authors reasoned from general knowledge instead of grepping the codebase:

1. **Firebase GitHub App install** (§4.0) — claimed as a required step, but all deploys use `FIREBASE_SERVICE_ACCOUNT` key auth. Cost ~15 min of Duong hunting a Console option that doesn't exist.
2. **Discord relay on Hetzner VPS** — architecture/*.md still said "Hetzner" but the VPS was retired; relay isn't deployed anywhere currently. Wasted a round of SSH instructions.
3. **Discord webhook secrets in the 17-secret list** — listed as required but never provisioned in the source repo either. Script has an explicit `skipping notification` guard; workflows run green without them.

**Fix:** post-migration ADR for new Sonnet agent **Orianna** who runs grep-style evidence verification on every plan promotion (`plan-promote.sh` mandatory gate) and does quarterly memory audits to catch drift (Hetzner→GCE pattern). Agent definition rules updated to require "Evidence:" lines for any external-integration citation.

## Sequential spawns > TeamCreate for phase-gated work on Max

TeamCreate makes sense when 3+ agents need concurrent coordination. Migration phases were heavily sequential with long idle stretches — TeamCreate teammates die on cache TTL (5 min sliding), so their wake-ups would be cache-cold anyway. Sequential spawns that close cleanly + coordinate via TaskList is cheaper and just as effective.

## Max x20 quota ≠ API billing

User on Max subscription burns quota (50-800 prompts/5h window) weighted by context size, not per-token dollars. Every message resends full conversation history. `/clear` is the single most effective lever Anthropic docs cite. Implication: don't run Evelynn sessions for >3-4h — close + resume fresh via handoff shards. Context >200K becomes expensive fast.

## GitHub fine-grained PAT limitation

Fine-grained PATs only see repos owned by the token's resource owner. Collaborator access on a different user's repo is **not** enough. Classic PAT with `repo` + `workflow` scope is the only viable path for cross-user-account agent automation. Org ownership would unlock fine-grained but requires repo restructure.

## Account-role inversion

Previous assumption: `Duongntd` = owner/bypass, `harukainguyen1411` = agent. Correct: `harukainguyen1411` = human/owner/bypass/reviewer, `Duongntd` = agent/collaborator/no-bypass/pusher. Fixed across memory files in commit `80cd16f`. Implication for future agent PAT minting: always from Duongntd.

## Squash vs preserve-history choice matters

strawberry-app used squash (single orphan commit) because code-history didn't need preservation and broke nothing. strawberry-agents used `filter-repo --invert-paths` to preserve 914 commits because agent memory files reference SHAs. Rule: squash public/code repos, preserve private/memory repos.

## Discord webhook secrets are a false alarm when relay isn't deployed

The `notify-discord-*.js` scripts have `if (!webhookUrl || !webhookSecret) { console.log("skipping"); process.exit(0); }`. Missing secrets are non-fatal. Worth remembering before treating a secret-paste list as mandatory.

## Cross-references

- Session memory: `agents/evelynn/memory/last-sessions/cca80ba9.md`
- Migration plan: `plans/approved/2026-04-19-public-app-repo-migration.md`
- Companion plan: `plans/approved/2026-04-19-strawberry-agents-companion-migration.md`
- Yuumi fact-check report: `assessments/2026-04-18-migration-plan-factcheck.md`
