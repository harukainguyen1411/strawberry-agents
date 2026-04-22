# PR Rules

Rules for all pull requests. Implementation PRs live in `harukainguyen1411/strawberry-app` (code). Plans commit directly to `harukainguyen1411/strawberry-agents` main (never via PR).

## Required Fields

- **Author line** — include `Author: <agent-name>` in the PR description body (not the title). This identifies which agent did the implementation.
- **Documentation checklist** — check the PR template documentation checklist before submitting. If the template doesn't render automatically, use `gh pr create --template` or paste the checklist manually.

## Documentation Updates

If your change touches any of the following, update the relevant docs **in the same PR**:

- `architecture/` — system architecture, platform parity, MCP servers, git workflow
- `.claude/agents/*.md` — subagent definitions
- `scripts/` — key scripts table in `architecture/key-scripts.md`
- Plugins — update `architecture/plugins.md` if new plugins are added or removed
- Features or integrations — update the relevant `README.md`

## Branch and PR Flow

- Use `scripts/safe-checkout.sh <branch>` to create a branch — never raw `git checkout -b`.
- Use `git worktree` for isolation. See `architecture/git-workflow.md` for full branch strategy.
- Implementation work goes through a PR. Plans commit directly to main (never via PR).
- Never `git rebase` — always merge.
- Never push `--force` to main.

## Commit Prefix

All commits (including on feature branches) use `chore:` or `ops:` prefix. The pre-push hook enforces this on main. See `#rule-chore-commit-prefix` in root `CLAUDE.md`.

## Account Roles for PRs

| Account | Role |
|---------|------|
| `Duongntd` | Agent pusher — opens PRs, pushes commits, manages branches in `strawberry-app` |
| `harukainguyen1411` | Human reviewer — approves PRs, merges. Has admin bypass (break-glass only). |

PRs are opened in `harukainguyen1411/strawberry-app`. Agents must not use `--admin` or any branch-protection bypass, and must not merge a red PR. Per rule 18, an agent may merge its own PR once (a) all required status checks are green and (b) one approving review from an account other than the PR author is in place — see `CLAUDE.md` rule 18.

## QA Gate (Rule 16)

Before opening a UI or user-flow PR, **Akali** (`.claude/agents/akali.md`) must
run the full **Playwright MCP** flow (`mcp__plugin_playwright_playwright__*` tool
family) with video + screenshots and diff against the Figma design.

- Report lives under `assessments/qa-reports/` and is linked in the PR body via a
  `QA-Report: <path-or-url>` line.
- A `QA-Waiver: <reason>` line is accepted in lieu when Akali cannot run.
- Enforced by `.github/workflows/pr-lint.yml` — PR cannot merge with a missing
  marker on UI/user-flow PRs. Failure message references **Rule 16** and **Akali**.
- **Non-UI and non-user-flow PRs are exempt.**

_User-flow_ definition (glossary): new routes, new forms, state-transition changes,
auth flows, session lifecycle changes — even when there is no visual pixel delta.

See also: repo-root `CLAUDE.md` rule 16 (`#rule-qa-agent-pre-pr`) and
`.claude/agents/akali.md` for Akali's full configuration and Playwright MCP setup.

## Review Team Protocol

Every PR goes through a three-agent review team (TeamCreate):

| Role | Agent | Responsibility |
|---|---|---|
| Implementer | Katarina (or executor who built the PR) | Fixes all issues raised by reviewer |
| Plan author | Whoever wrote the plan (Swain, Syndra, Pyke, etc.) | Verifies implementation matches plan intent |
| Reviewer | Lissandra | Logic, security, edge cases — loops until clean |

**Loop:**
1. Lissandra reviews → posts findings as `gh pr comment`
2. If issues: messages Katarina with the list
3. Katarina fixes → pushes → messages Lissandra "fixes pushed, please re-review"
4. Repeat until Lissandra confirms clean
5. Lissandra messages Evelynn: "PR #N is clean — ready to merge"
6. Evelynn merges + shuts down the team via SendMessage shutdown_request

Evelynn creates the team with TeamCreate, spawns all three agents with `team_name`, and waits for Lissandra's clean signal before merging.

## Merge

Evelynn merges after Lissandra confirms clean. Never merge before the review loop completes.

## Work-scope anonymity {#work-scope-anonymity}

Work-concern PRs land on repos under the `missmp/` GitHub organisation, where Duong's MMP
teammates and colleagues can see every review body, comment, and commit message. Agent-system
internals must never leak into those surfaces.

### Scope signal

A repo is considered **work-scope** when `git remote get-url origin` matches the regex
`[:/]missmp/`. Personal-concern repos (e.g. `harukainguyen1411/strawberry-app`) are
unaffected — enforcement is a no-op there.

### Denylist surfaces

The following categories of tokens are blocked on work-scope surfaces:

| Category | Examples |
|----------|---------|
| Agent first-names | Senna, Lucian, Evelynn, Sona, Viktor, Jayce, Azir, Swain, Orianna, Karma, Talon, Ekko, Heimerdinger, Syndra, Akali, Ahri, Ori |
| GitHub handles | `strawberry-reviewers`, `strawberry-reviewers-2`, `harukainguyen1411`, `duongntd99` |
| Email domain | `*@anthropic.com` |
| AI attribution trailer | `Co-Authored-By: Claude` |

The denylist token table is the single source of truth in
`scripts/hooks/_lib_reviewer_anonymity.sh`. Word-boundary matching (`grep -wi`) prevents
false positives on substrings.

### Enforcement paths

1. **Pre-commit hook** (`scripts/hooks/pre-commit-reviewer-anonymity.sh`) — scans
   `.git/COMMIT_EDITMSG` before every commit in a work-scope repo. Hit → exit 1, commit
   blocked with guidance.

2. **`scripts/reviewer-auth.sh` pre-submit scan** — before executing any `gh pr review`
   or `gh pr comment` call, resolves the PR's head repository. If it matches `missmp/`,
   the `--body` value is scanned. Hit → exit 3, request NOT posted.

### Guidance for reviewer agents

Sign reviews with a generic role tag (e.g. `-- reviewer`) instead of an agent name.
Treat a `reviewer-auth.sh` exit-3 rejection as a drafting bug — rewrite the body and
retry.

See also: `architecture/cross-repo-workflow.md` for the multi-repo context.
