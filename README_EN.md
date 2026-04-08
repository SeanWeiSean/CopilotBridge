# CopilotBridge

[中文](README.md) | [日本語](README_JA.md) | [한국어](README_KO.md) | [Español](README_ES.md)

Extend GitHub Copilot's power to any tool and workflow — use Copilot models (Claude, GPT, Gemini) through a single OpenAI-compatible API endpoint in Claude Code, Cursor, custom scripts, CI/CD, and anywhere that supports the OpenAI API.

## Why CopilotBridge?

You already have a GitHub Copilot subscription, but its capabilities are locked inside VS Code and GitHub's UI. CopilotBridge lets you:

- Use Copilot's Claude/GPT models in **Claude Code**
- Call Copilot models from **Cursor**, **Continue**, and other IDE plugins
- Integrate AI into **automation scripts and CI/CD**
- Access models via API from **any device** — no browser login needed
- Authenticate once, **use everywhere**

## Deployment Options

| Method | Best For | Cost |
|--------|----------|------|
| **🖥️ Local** | Personal use, quickest start | Free |
| **🚂 Railway** | No local Docker, access anywhere | Free trial ($5 credit, ~1 month) |
| **☁️ Azure** | Long-term stability, enterprise features | Azure pricing |

---

## 🖥️ Run Locally (Quickest Start)

Just Docker, 3 steps:

### 1. Start the Proxy

```bash
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

### 2. Authenticate with GitHub

The terminal will display:
```
Please visit https://github.com/login/device and enter code XXXX-YYYY to authenticate.
```
Open the link, enter the code, authorize. Done.

### 3. Use It

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

> Credentials persist in Docker volume `litellm_config` — no re-auth on next start.

---

## 🚂 Railway Deployment (No Local Docker)

Railway offers a **$5 free trial** (~1 month). No local tools needed.

### 1. Fork & Deploy

1. **Fork** this repo to your GitHub account
2. Go to [railway.com](https://railway.com/) and sign in with GitHub
3. If prompted, **Install the Railway GitHub App**
4. **New Project** → **Deploy from GitHub Repo** → select `CopilotBridge`

### 2. Configure

**Variables** (service → Variables → New Variable):

| Variable | Value |
|---|---|
| `LITELLM_MASTER_KEY` | A strong key (32+ random chars): `echo "sk-$(openssl rand -hex 16)"` |
| `RAILWAY_RUN_UID` | `0` |

> **🚨 You MUST set `LITELLM_MASTER_KEY`!** Without it, anyone can call AI models through your proxy — **significant financial loss and account risk**.

**Networking** (Settings → Networking → **Generate Domain**)

**Dockerfile Path** (Settings → Build → `railway/Dockerfile`)

**Disable Auto-deploy** (Settings → Source → **Disconnect**)

### 3. Authenticate

Visit your Railway URL → **Begin Authentication** → enter device code → authorize (~10 sec) → proxy is live.

### 4. Use It

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## ☁️ Azure Deployment (Recommended for Long-term Use)

Azure Container Apps offers Volume persistence, VNet isolation, and enterprise-grade features.

Use AI tools like Claude Code with [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) to complete the entire deployment, or use the automation scripts in `scripts/`.

---

## Client Configuration

**Claude Code:**
```bash
export ANTHROPIC_BASE_URL="https://your-proxy-url"
export ANTHROPIC_AUTH_TOKEN="YOUR_MASTER_KEY"
export ANTHROPIC_API_KEY="YOUR_MASTER_KEY"
```

**OpenAI-compatible clients (Cursor, Continue, etc.):**
```bash
export OPENAI_API_BASE="https://your-proxy-url/v1"
export OPENAI_API_KEY="YOUR_MASTER_KEY"
```

## Available Models

| Provider | Models |
|----------|--------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **Other** | minimax-m2.5 |

## Token Refresh

- **Copilot API key** (~30 min expiry): LiteLLM **auto-refreshes** — no action needed
- **GitHub OAuth token**: Long-lived, only invalidated if you revoke it manually

You typically **never need to re-authenticate**.

## Roadmap

- [ ] Railway OAuth credential persistence (auto Volume setup)
- [ ] Railway one-click deploy template (Deploy Button)
- [ ] AWS Bedrock as additional model backend
- [ ] Google Cloud Vertex AI support
- [ ] Azure OpenAI Service support
- [ ] Enhanced web admin panel (usage stats, model switching)
- [ ] Multi-user API key management
- [ ] Docker Compose one-click local deployment
- [ ] Auto-discover and update available model list

## License

MIT
