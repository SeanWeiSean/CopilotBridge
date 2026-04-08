# CopilotBridge

[中文](README.md)

A shared LiteLLM proxy that lets your team use GitHub Copilot models (Claude, GPT, Gemini) through a single OpenAI-compatible API endpoint — no per-machine Docker or browser auth needed.

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
| `LITELLM_MASTER_KEY` | A secret key of your choice, e.g. `sk-my-secret-key-123` |
| `RAILWAY_RUN_UID` | `0` |

> ⚠️ If you skip `LITELLM_MASTER_KEY`, the proxy runs without authentication — anyone can use it.

**Networking** (service → Settings tab → Networking):

- Under **Public Networking**, click **Generate Domain**
- You'll get a URL like `https://your-app-production.up.railway.app`

**Dockerfile Path** (service → Settings tab → Build):

- Set **Custom Dockerfile Path** to `railway/Dockerfile`

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

### Re-authentication

If the GitHub OAuth token expires, the container will crash and restart into the Auth Wizard automatically. Just visit the URL again and complete the flow.

To manually trigger re-auth, call:

```bash
curl -X POST https://your-app.up.railway.app/auth/reset \
  -H "Authorization: Bearer YOUR_MASTER_KEY"
```

> **Tip:** Attach a [Railway Volume](https://docs.railway.com/guides/volumes) mounted at `/root/.config` to persist OAuth credentials across redeploys.

---

## Azure Deployment

For Azure Container Apps deployment, see [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) and the `scripts/` directory.

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
