# Personal AI Stack — Recommendation

*Prepared by Syndra, 2026-04-05 (v2 — revised with Duong's input)*

## The Problem

Four distinct needs, each with different requirements:

| Need | Key requirement |
|---|---|
| Agent system (code production) | Reliable, autonomous, tool-use capable |
| Personal assistant (life admin) | Voice-first, mobile, reminders, idea capture |
| Casual learning | Coffee, health, fitness, philosophy, languages, curiosity-driven |
| Work coding | Already covered by Team subscription |

Key constraint: Evelynn is the code project coordinator — not a life admin assistant.

---

## 1. Agent System (Strawberry) — Claude API

**Recommendation: Claude API (pay-per-token)**

This is non-negotiable. Your agent system needs:

- Autonomous execution (auto mode — currently API or Team only)
- Tool use (MCP servers, bash, file operations)
- Multiple concurrent agents (parallel sessions)
- Predictable, usage-based billing

**Why not a subscription?**

- Pro/Max don't support auto mode or Claude Code CLI reliably for agents
- Team plan requires 5 seats minimum — you're one person
- API gives you exact cost control and per-agent tracking via separate API keys

**Setup:**

- Anthropic API key in each agent's `settings.local.json`
- Model: Sonnet for routine tasks, Opus for complex reasoning/design
- Prompt caching is automatic in Claude Code — 90% cheaper on cached reads
- Budget: estimate ~$30-80/month depending on usage intensity

**Cost optimization:**

- Use Sonnet as default for most agents (Katarina, Fiora, Bard, etc.)
- Reserve Opus for Syndra, Swain, and Evelynn (strategy/architecture/coordination)
- Haiku for simple routing or classification tasks if you build any

---

## 2. Personal Assistant — Gemini on Samsung

**Recommendation: Google Gemini Advanced (~$20/month)**

You already have Gemini as the default assistant on your Galaxy S24 Ultra. This is the right call. Don't switch — double down on it.

**Why Gemini wins here:**

- **Voice-first by default** — long-press power button, start talking. Zero friction.
- **Samsung deep integration** — can set reminders, create calendar events, open apps, control device settings natively
- **Google ecosystem** — syncs with Google Calendar, Gmail, Keep, Tasks automatically
- **Persistent memory** — Gemini remembers context across conversations (your preferences, ongoing topics)
- **Idea capture** — "Hey Google, remember that I want to try pour-over coffee" → saved and retrievable
- **Multilingual** — solid for language learning conversations since you're interested in that

**What Gemini Advanced adds over free:**

- Longer, deeper conversations
- 1M token context (can process documents, long articles)
- Gemini in Gmail, Docs, Sheets (useful for life admin)
- Better reasoning for nuanced questions

**What to use it for:**

- Quick reminders: "Remind me to call the dentist Monday at 9am"
- Idea capture: voice-dump thoughts while walking, review later
- Daily planning: "What's on my calendar today?"
- Casual questions: "What's the difference between Arabica and Robusta?"
- Language practice: "Let's practice German conversation about ordering food"

**Why NOT ChatGPT for this role:**

- No native Samsung integration — you'd have to open the app manually
- ChatGPT voice is good but it's an extra step vs Gemini being the system default
- You'd be fighting against the OS instead of working with it

**Evelynn's role stays clean:** She's your code project PM and agent coordinator. Personal life goes through Gemini on your phone. No overlap, no confusion.

---

## 3. Casual Learning — Gemini + ChatGPT

**Recommendation: Gemini Advanced (primary) + ChatGPT Plus (optional, for depth)**

Your learning needs are conversational and curiosity-driven — not academic research. This changes the recommendation significantly. You don't need Perplexity.

**Gemini Advanced (you're already paying for it as your assistant):**

- Great for "explain X to me" — coffee brewing, fitness science, philosophy basics
- Web-connected — can pull current information, cite sources when asked
- Voice conversations — learn while commuting, cooking, walking
- "Deep Research" mode for when you want to go deeper on a topic (spawns a multi-step research agent)
- Language learning — can hold conversations in target languages, correct your grammar

**ChatGPT Plus (~$20/month) — optional add-on for when Gemini isn't enough:**

- Better at Socratic dialogue ("don't just tell me, help me figure it out")
- Memory: ChatGPT remembers things across conversations. Example: you tell it "I'm interested in stoicism and I prefer practical examples over theory" — it adjusts all future philosophy conversations accordingly. You can also tell it facts about yourself ("I work out 3x/week", "I drink espresso") and it'll reference them naturally.
- Canvas mode: interactive workspace for working through concepts, translations, study plans
- Slightly better at nuanced topics (philosophy, politics) where you want pushback and multiple perspectives

**My honest take:** Start with Gemini only. It's already on your phone, already paid for (if you get Advanced for the assistant role), and handles 80% of casual learning. Add ChatGPT Plus later only if you find yourself wanting deeper, more structured learning sessions — like working through a philosophy reading list or seriously studying a new language.

---

## Summary Stack

| Need | Tool | Cost |
|---|---|---|
| Agent system | Claude API | ~$30-80/month (usage-based) |
| Personal assistant + reminders | Gemini Advanced (Samsung) | ~$20/month |
| Casual learning | Gemini Advanced (same sub) | $0 (included above) |
| Deep learning sessions (optional) | ChatGPT Plus | ~$20/month |
| Work coding | Team subscription (employer-paid) | $0 to you |

**Minimum cost: ~$50-100/month** (API + Gemini Advanced)
**With ChatGPT: ~$70-120/month**

---

## What I Would NOT Do

1. **Don't use Claude Max/Pro for agents** — rate limits will choke multi-agent workflows
2. **Don't pay for Perplexity** — your learning needs are conversational, not research-grade. Gemini covers it.
3. **Don't build an AI personal assistant** — Gemini on Samsung IS your personal assistant. It's already there.
4. **Don't mix Evelynn into life admin** — she's your code PM. Keep the boundary clean.
5. **Don't switch your Samsung default to ChatGPT** — Gemini's OS integration is the killer feature. Use ChatGPT as a secondary app when you want depth.

---

## Migration Path

1. **Now:** Get your own Anthropic API key. Move agent system off work Team.
2. **Now:** Upgrade to Gemini Advanced if not already. Start using it intentionally for reminders, ideas, and learning.
3. **This week:** Set up a simple system — morning "what's my day" voice query, evening idea review.
4. **After 2 weeks:** Evaluate if Gemini covers your learning needs. If not, add ChatGPT Plus.
5. **Ongoing:** Evelynn stays in her lane — code coordination only.
