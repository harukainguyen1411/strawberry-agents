---
status: active
owner: bard
gdoc_id: 1QyZZCgAtWm054-Qx-sKmKKisc_W2tCpGWvAbRi0fCgs
gdoc_url: https://docs.google.com/document/d/1QyZZCgAtWm054-Qx-sKmKKisc_W2tCpGWvAbRi0fCgs/edit
---

# Discord Setup Guide — myapps Collaboration Hub

## 1. Create the Server

1. Open Discord → click **"+"** (left sidebar) → **Create My Own** → **For me and my friends**
2. Name: **myapps** (or whatever you prefer)
3. Upload an icon if you want (optional)

## 2. Channel Structure

Delete the default channels, then create categories and channels:

### 📋 INFO
| Channel | Type | Purpose |
|---|---|---|
| #welcome-and-rules | Text | Server intro, ground rules |
| #announcements | Text | Release notes, important updates |

### 💻 DEVELOPMENT
| Channel | Type | Purpose |
|---|---|---|
| #general-dev | Text | Day-to-day dev chat |
| #pr-and-issues | Text | GitHub webhook feed (automated) |
| #ideas-and-requests | Text | Feature ideas, user requests |

### 🎮 HANGOUT
| Channel | Type | Purpose |
|---|---|---|
| #off-topic | Text | Non-dev chat |
| voice-chat | Voice | Voice/screen share |

**How:** Right-click category area → Create Category → name it → then click "+" next to category to add channels.

## 3. Roles & Permissions

Go to **Server Settings → Roles** and create three roles:

### @admin
- Full Administrator permissions
- Assign to yourself

### @contributor
- View Channels, Send Messages, Embed Links, Attach Files, Add Reactions
- Read Message History, Connect (voice), Speak (voice)
- Use Application Commands
- Access to all categories

### @viewer
- View Channels, Read Message History, Add Reactions
- Connect + Speak in HANGOUT only
- **Deny** Send Messages in INFO and DEVELOPMENT categories
- Full access in HANGOUT

**How to restrict @viewer per category:** Click category name → Edit Category → Permissions → add @viewer role → toggle Send Messages OFF for INFO and DEVELOPMENT.

## 4. GitHub Webhook → #pr-and-issues

1. Click **#pr-and-issues** → Edit Channel (gear icon) → **Integrations** → **Webhooks**
2. Click **New Webhook** → name it "GitHub" → **Copy Webhook URL**
3. Go to https://github.com/Duongntd/myapps → **Settings** → **Webhooks** → **Add webhook**
4. Payload URL: paste the Discord webhook URL and append `/github` at the end
   - Example: `https://discord.com/api/webhooks/123/abc/github`
5. Content type: **application/json**
6. Under "Which events would you like to trigger this webhook?", select **Let me select individual events**:
   - **Pushes**
   - **Pull requests**
   - **Issues**
   - **Issue comments** (optional but useful)
7. Click **Add webhook**

Test it by pushing a commit or opening an issue — should appear in #pr-and-issues within seconds.

## 5. Pin Getting-Started Message

Go to **#general-dev**, post this message, then right-click → **Pin Message**:

> Welcome to myapps dev! Repo: https://github.com/Duongntd/myapps
> PRs and issues auto-feed into #pr-and-issues.
> Got an idea? Post it in #ideas-and-requests.

## Total time: ~10 minutes
