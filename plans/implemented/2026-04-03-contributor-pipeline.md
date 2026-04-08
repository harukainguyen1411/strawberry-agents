---
status: proposed-v2
owner: swain
gdoc_id: 1YD0hdUtXLs-9I9bRfgUAhsgElvkzvar5VHUKNjJHvTc
gdoc_url: https://docs.google.com/document/d/1YD0hdUtXLs-9I9bRfgUAhsgElvkzvar5VHUKNjJHvTc/edit
---

# Contributor Pipeline Architecture (v2)

**Goal:** Friends submit ideas via Discord → LLM triages → Claude Code builds it → preview → Duong deploys.

## Recommended Architecture

```
Discord Forum Channel (#suggestions)
    ↓ new post detected by bot
LLM Triage (Gemini Flash / Claude Haiku)
    ↓ structures request → creates GitHub Issue
Self-hosted Runner (Duong's machine or always-on VPS)
    ↓ Claude Code CLI (subscription-authenticated)
Claude Code session
    ↓ pushes branch + opens PR
Firebase Hosting Preview Channel
    ↓ preview URL posted back to Discord thread
Contributor approves via Discord button
    ↓ bot labels PR "approved"
Duong merges → production deploy
```

## Component Decisions

### 1. Discord → Triage: Forum Channel + LLM Intake

Contributors post in a **Forum channel** (`#suggestions`) in the strawberry Discord server. Lower friction than slash commands — just write a post with a title and description.

A Discord bot watches for new forum posts and:

1. Sends the post content to a **lightweight LLM** (Gemini 2.0 Flash or Claude Haiku) for triage:
   - Classifies: bug, feature, enhancement, question
   - Extracts: target app, description, acceptance criteria
   - Assesses feasibility (reject nonsense/out-of-scope)
2. Creates a **structured GitHub Issue** from the triage output
3. Triggers the Claude Code workflow (via `workflow_dispatch` or direct script)
4. Replies in the Discord thread with status + issue link

**Why Forum over slash commands:** For a small trusted group, a forum post is more natural. It creates a persistent thread per suggestion — contributors can add context, the bot posts updates, and everything stays organized.

**Why LLM triage:** Raw contributor text needs interpretation. Structures the input so Claude Code gets a clean, actionable spec. Also catches spam or out-of-scope requests before burning Claude Code time.

**Triage LLM: Gemini 2.5 Flash-Lite (free tier).** Google offers a free tier with no credit card required: 15 RPM, 1,000 requests/day, 250K tokens/minute. For a small contributor group doing a few suggestions per day, this is effectively unlimited and costs $0. No budget cap or rate limiting needed — the free tier's own limits are the cap. If the free tier ever gets restricted, Groq (free tier with Llama 3) is the fallback.

### 2. Claude Code Runtime: Self-Hosted GitHub Actions Runner

**The subscription problem:** Duong uses Claude on a subscription plan, not API billing. Claude Code CLI authenticates via `claude login` (OAuth), not an API key. This means Claude Code must run on a machine where Duong has authenticated — not a GitHub-hosted runner where you'd need `ANTHROPIC_API_KEY`.

**Solution: Self-hosted GitHub Actions runner.**

- A persistent machine (Duong's Mac, a cheap VPS, or a Raspberry Pi) runs the GitHub Actions runner agent
- Duong authenticates Claude Code CLI once on that machine (`claude login`)
- GitHub Actions workflows dispatch to this self-hosted runner via `runs-on: self-hosted`
- The workflow: checks out the repo, creates a branch, runs `claude -p "implement: <issue description>"`, commits, pushes, opens a PR

**Recommended VPS: Hetzner Cloud CX22** (Falkenstein or Helsinki DC)

- **Spec:** 2 vCPU (shared), 4 GB RAM, 40 GB NVMe SSD, 20 TB traffic
- **Price:** €3.79/mo (~$4.15/mo)
- **Why Hetzner over alternatives:**
  - Contabo is cheaper ($3.96/mo for 8 GB) but has worse reliability, slower support, and inconsistent network performance — not worth the risk for an always-on runner
  - DigitalOcean starts at $12/mo for comparable specs — 3x the cost for no meaningful benefit here
  - Hetzner has the best price-to-performance ratio in Europe, NVMe storage, and solid uptime track record
- **Setup:** Install GitHub Actions runner agent + Claude Code CLI, authenticate once via `claude login`, done

**Why not API-based:** Duong's subscription doesn't provide API keys. Switching to API billing just for this pipeline adds unnecessary cost when subscription already covers Claude Code CLI usage.

**Why not Claude Code remote agents:** Not yet GA as of April 2026. When available, this would be the ideal replacement — no self-hosted runner needed. Design the workflow_dispatch interface so it can swap to remote agents later with minimal changes.

### 3. Preview: Firebase Hosting Preview Channels

Since the project uses **Firebase Hosting** (not Vercel), use Firebase's built-in preview channels:

```bash
firebase hosting:channel:deploy pr-<number> --expires 7d
```

This creates a temporary preview URL like `https://PROJECT--pr-123-HASH.web.app`. The GitHub Actions workflow runs the Firebase deploy after Claude Code pushes the branch.

**Integration flow:**
1. Claude Code commits and pushes the branch
2. Workflow runs `firebase hosting:channel:deploy` on the self-hosted runner
3. Preview URL is posted back to the Discord forum thread
4. Preview auto-expires after 7 days

**Why Firebase preview channels:** Already using Firebase Hosting. No new service to add. Free on the Spark plan for reasonable usage.

### 4. Approval → Deploy Flow

1. Bot posts preview URL + "Approve" / "Request Changes" buttons in the Discord thread
2. "Approve" → bot adds `approved` label to the GitHub PR
3. "Request Changes" → bot posts the feedback as a PR comment, optionally triggers another Claude Code pass
4. Duong reviews and merges at his convenience
5. Merge to `main` triggers production deploy via existing Firebase CI/CD

**Duong stays as gatekeeper.** Contributors don't get merge or deploy access.

### 5. Security

- **Claude Code runs on a trusted self-hosted runner** — Duong controls the machine
- **Contributors cannot inject code** — Claude Code interprets natural language descriptions, not executable input
- **Branch protection on `main`** — PRs require Duong's merge
- **Role-based access:** Discord `Contributor` role can post in #suggestions, `Admin` role can override/manage. No rate limiting needed for a small trusted group
- **LLM triage acts as a filter** — rejects out-of-scope or malformed requests before they reach Claude Code

### 6. Cost Estimate

| Component | Cost |
|---|---|
| Discord bot hosting | ~$0 (existing infra) |
| Hetzner CX22 VPS (self-hosted runner) | ~€3.79/mo (~$4.15/mo) |
| Claude Code CLI | $0 (covered by subscription) |
| LLM triage (Gemini 2.5 Flash-Lite — free tier) | $0 (see below) |
| Firebase preview channels | $0 (Spark plan) |
| **Total** | **~$4.15/mo fixed, $0 per suggestion** |

## Implementation Order

1. **Self-hosted runner setup** — authenticate Claude Code CLI, register as GitHub Actions runner
2. **Discord bot** — watches #suggestions forum, calls LLM for triage, creates GitHub issues (Katarina)
3. **GitHub Actions workflow** — dispatched by bot, runs Claude Code on self-hosted runner, opens PR (Ornn)
4. **Firebase preview deploy** — add to workflow, post URL back to Discord
5. **Approval buttons** — Discord interaction → GitHub label (second pass on bot)

## Future Migration Path

When Claude Code remote agents hit GA:
- Replace self-hosted runner with remote agent trigger
- Keep everything else identical (Discord bot, triage, preview, approval flow)
- The `workflow_dispatch` interface is the seam — swap the runner, keep the contract
