---
agent: evelynn
date: 2026-04-19
topic: github-ruleset-ui-bypass-broken
related:
  - plans/implemented/2026-04-19-branch-protection-restore.md
---

# GitHub rulesets' UI bypass is broken for `pull_request` rule on personal repos

## What happened

Duong wanted UI-only merge bypass for his human owner account (`harukainguyen1411`) on the user-owned `strawberry-app` repo — no CLI auth, so agents couldn't misuse admin tokens.

Camille wrote a ruleset plan with `bypass_actors[].actor_type: "User"` and `bypass_mode: "pull_request"`. Ekko applied it. Merge UI blocked with "Merging is blocked due to pending merge requirements" and no bypass checkbox.

I iterated three times, each time changing one knob and re-testing:
1. `bypass_mode: "pull_request"` → `"always"`. Still blocked.
2. `actor_type: "User", actor_id: 273533031` → `actor_type: "RepositoryRole", actor_id: 5`. API response flipped `current_user_can_bypass` from `"never"` to `"always"`. UI still blocked.
3. **Finally searched**. Community discussion #113172 (open over a year): GitHub's ruleset UI bypass is known broken for `pull_request` rule type on personal repos. No fix from GitHub.

Workaround: abandon rulesets entirely, apply classic branch protection with `enforce_admins: false`. Classic protection's admin bypass UI works reliably — small "Bypass branch protections" checkbox on merge button.

## The mistake

Three API-knob iterations before I searched. Each iteration cost a real turn.

If I'd searched after the first failed iteration — when `current_user_can_bypass: "never"` persisted despite a valid-looking config — I'd have saved the whole evening.

## The rule

**When a GitHub API says "this should work" but the UI says "this is blocked": search before iterating.**

Signal: the API return field contradicts the observed UI behavior. That's not a config bug, it's a platform bug. The API layer and the UI layer are different codepaths, and GitHub's rulesets layer has known divergences from classic protection.

Specific gotchas from this session:
- `bypass_mode: "pull_request"` means **bypass applies at PR creation/update**, not at merge time.
- `actor_type: "User"` in `bypass_actors` silently doesn't grant bypass on personal (user-owned) repos; `RepositoryRole` (admin role id 5) does at the API level — but UI still may not expose the bypass affordance.
- For the `pull_request` rule type specifically, the bypass checkbox is known missing from the merge UI on personal repos.

## Signal-of-brokenness checklist

When setting up ruleset bypass:
1. Check `current_user_can_bypass` in the API response. If it says `never` despite a valid-looking config, stop iterating and search.
2. Verify the rule type has a known-working bypass UI. `required_status_checks` → yes; `pull_request` → no (as of 2026-04-19).
3. For personal repos, default to **classic branch protection with `enforce_admins: false`**. It's pre-rulesets but works.

## References

- [Repo rulesets deny me from merging PR — community discussion #113172](https://github.com/orgs/community/discussions/113172)
- [Bypass list for Ruleset not applying to status checks and pull requests #86534](https://github.com/orgs/community/discussions/86534)
- `plans/implemented/2026-04-19-branch-protection-restore.md` — Corrections #1, #2, #3 document the full arc
