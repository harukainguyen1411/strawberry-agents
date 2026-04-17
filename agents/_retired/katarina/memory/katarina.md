# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions (recent)
- 2026-04-14 (subagent, git-status-cleanup): Executed Groups 1-4 of git-status-cleanup plan. Added gitignore patterns (build artifacts, sentinels, .worktrees/, firebase-debug.log). Deleted stray screenshots/sentinels. Committed UBCS slide tools + approved plan. Removed 17 worktrees total (10 merged from plan + 4 from Evelynn + 3 per Duong runtime instruction). Pruned 5 .claude/worktrees/. Closed PR #102. Deleted 22 local branches. Working tree clean. feat-bee-gemini-intake is the only remaining user worktree.
- 2026-04-13 (subagent, ubcs-slide-team): Completed ubcs-slide-builder.py. Style guide constants replace hardcoded values. add_header() reads from header_bar.* with fallbacks. No commit per task spec.
- 2026-04-13 (subagent, fix-bee-storage-rules): Fixed storage.rules — corrected path bee->bee-temp, hardcoded real UID. Gitleaks false-positive suppressed with gitleaks:allow. PR #104.
- 2026-04-13 (subagent, retro-skill-body-strip): Wrote scripts/strip-skill-body-retroactive.py. Stripped 810 KB of skill-body leaks from 18 transcripts. Merged to main.
- 2026-04-12 (subagent, deployment-architecture): Phase 1 + Phase 5 of deployment architecture plan. Standalone Vite packages + portal conversion. PR #100.
- 2026-04-11 (subagent, S10): cloudflare-gcp-mcp-servers plan. MCP start scripts committed. .mcp.json blocked by harness — Evelynn handles.
- 2026-04-11 (subagent, S7): PR #89 review loop complete. DEPLOY_REPO_ROOT guard + NSSM fixes + npm ci. PR approved by Lissandra.
- 2026-04-11 (subagent, B5): Bee MVP task B5. worker.ts + docx.ts + index.ts. PR #75.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Vue 3 + Vite + Firebase + Tailwind. Strict pre-commit hooks (typecheck + tests + lint).

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- All commits use `chore:` or `ops:` prefix (enforced by pre-push hook on main)
- .claude/ directory writes are BLOCKED by harness in subagent mode — cannot update .claude/agents/*.md or .claude/skills/*.md from a subagent invocation
- github-triage-pat.txt is stale; github-triage-pat.age is invalid (EOF error). GitHub API calls fail. Need fresh token before PR automation works.
- Gitlinked worktrees (.worktrees/feat-discord-per-app-channels was tracked as 160000 submodule) require `git rm` not just `git worktree remove` to clean properly.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first.
