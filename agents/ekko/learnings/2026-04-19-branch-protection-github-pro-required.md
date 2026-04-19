# Branch Protection Requires GitHub Pro on Private Repos

Date: 2026-04-19
Session: ekko s33

## Lesson

Both classic branch protection (`PUT /branches/{branch}/protection`) and rulesets
(`POST /repos/{owner}/{repo}/rulesets`) return 403 with message
"Upgrade to GitHub Pro or make this repository public to enable this feature."
when the repo is private and the account is on the free plan.

This applies even when the calling account is the repo owner.

## Options to Unblock

1. Upgrade the owning account (`harukainguyen1411`) to GitHub Pro.
2. Make `strawberry-agents` public (changes threat model — review before doing).
3. Revise the plan to drop the branch-protection requirement and rely on
   agent discipline + PR review workflow instead.

## Auth Note

When running protection calls as `harukainguyen1411`, leave auth as-is after the
call — do not switch back inside the agent session. Remind Duong to run
`gh auth switch --hostname github.com --user Duongntd` to restore normal workflow.
