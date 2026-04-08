# CopilotBridge

[中文](README.md) | [日本語](README_JA.md) | [한국어](README_KO.md) | [Español](README_ES.md)

A shared LiteLLM proxy that lets your team use GitHub Copilot models (Claude, GPT, Gemini) through a single OpenAI-compatible API endpoint — no per-machine Docker or browser auth needed.

> **Deployment options:**
> - **Railway (Quick Start)**: Free trial credit ($5), good for personal use and testing (~1 month free). Follow the guide below.
> - **Azure Container Apps (Recommended for Production)**: Best for teams and long-term use. See [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) — you can deploy it entirely with AI tools like Claude Code.

## Quick Deploy on Railway

### 1. Fork & Deploy

1. **Fork** this repo to your GitHub account
2. Go to [railway.com](https://railway.com/) and sign in with your GitHub account
3. If prompted, **Install the Railway GitHub App** to grant access to your repos
4. **New Project** → **Deploy from GitHub Repo** → select your forked `CopilotBridge` repo
5. Railway will start building automatically

### 2. Configure

After the first deploy (it will show the Auth Wizard), configure these in Railway:

**Variables** (service → Variables tab → New Variable):

| Variable | Value |
|---|---|
| `LITELLM_MASTER_KEY` | A strong secret key (at least 32 random characters). Use a password generator, e.g. `sk-` + 32 random hex characters |
| `RAILWAY_RUN_UID` | `0` |

Generate a key (run in terminal):
```bash
# Linux / macOS
echo "sk-$(openssl rand -hex 16)"
# PowerShell
"sk-" + -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
```

> **🚨 You MUST set `LITELLM_MASTER_KEY`!** Without it, the proxy is completely open — anyone on the internet can call AI models through your proxy, consuming your GitHub Copilot quota, potentially causing **significant financial loss and account risk**.

**Networking** (service → Settings tab → Networking):

- Under **Public Networking**, click **Generate Domain**
- You'll get a URL like `https://your-app-production.up.railway.app`

**Dockerfile Path** (service → Settings tab → Build):

- Set **Custom Dockerfile Path** to `railway/Dockerfile`

**Disable Auto-deploy** (service → Settings tab → Source):

- Find **Branch connected to production** and click **Disconnect**
- This prevents code pushes from triggering redeployments (which would clear OAuth credentials)
- To update manually: `Cmd+K` → "Deploy Latest Commit"

### 3. Authenticate with GitHub Copilot

1. Open your Railway domain URL in a browser
2. You'll see the **CopilotBridge Auth Wizard**
3. Click **Begin Authentication**
4. A device code appears — click **Open GitHub** and enter the code
5. Authorize in GitHub (takes ~10 seconds)
6. The proxy automatically restarts into API mode

### 4. Use the Proxy

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**For Claude Code users:**

```bash
export ANTHROPIC_BASE_URL="https://your-app.up.railway.app"
export ANTHROPIC_AUTH_TOKEN="YOUR_MASTER_KEY"
export ANTHROPIC_API_KEY="YOUR_MASTER_KEY"
```

### Available Models

| Provider | Models |
|----------|--------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **Other** | minimax-m2.5 |

### Token Refresh

- **Copilot API key** (expires every ~30 min): LiteLLM **auto-refreshes** it — no action needed
- **GitHub OAuth token**: Long-lived, only invalidated if you manually revoke it in GitHub Settings or org policy changes

You typically **never need to re-authenticate**. If you do (e.g. switching GitHub accounts), trigger it manually:

```bash
curl -X POST https://your-app.up.railway.app/auth/reset \
  -H "Authorization: Bearer YOUR_MASTER_KEY"
```

After reset, the container restarts into the Auth Wizard. Visit the URL to complete a new OAuth flow.

> **Tip:** Attach a [Railway Volume](https://docs.railway.com/guides/volumes) mounted at `/root/.config` to persist OAuth credentials across redeploys.

---

## Azure Deployment (Recommended for Production)

Azure Container Apps is ideal for teams needing long-term stability, with Volume persistence, VNet isolation, and enterprise-grade features. Use AI tools like Claude Code with [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) to complete the entire deployment, or use the automation scripts in `scripts/`.

## Architecture

```
User / CI/CD
    │
    ▼
┌─────────────────────────┐
│  CopilotBridge Proxy    │
│  (LiteLLM on Railway)   │
│  LITELLM_MASTER_KEY     │
└────────────┬────────────┘
             │ GitHub OAuth token
             ▼
┌─────────────────────────┐
│  GitHub Copilot API     │
│  Claude, GPT, Gemini    │
└─────────────────────────┘
```

The proxy uses a three-layer token system:
- **Layer 1** — GitHub OAuth access token (long-lived, from Device Code Flow)
- **Layer 2** — Copilot API key (short-lived, auto-refreshed by LiteLLM every ~30 min)
- **Layer 3** — `LITELLM_MASTER_KEY` (your proxy access key, shared with clients)

## License

MIT
