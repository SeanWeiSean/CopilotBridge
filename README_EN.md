# CopilotBridge

[中文](README.md)

A reverse proxy for the GitHub Copilot API, exposing it as an OpenAI and Anthropic compatible service. Use Copilot models (Claude, GPT, Gemini) in Claude Code, Cursor, custom scripts, CI/CD, and anywhere that supports the OpenAI API.

> [!WARNING]
> This is a reverse-engineered proxy of GitHub Copilot API. **It is not supported by GitHub**, and may break unexpectedly. Use at your own risk.

> [!WARNING]
> **GitHub Security Notice:**
> Excessive automated or scripted use of Copilot (including rapid or bulk requests, such as via automated tools) may trigger GitHub's [abuse-detection systems](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies).
> You may receive a warning from GitHub Security, and further anomalous activity could result in temporary suspension of your Copilot access.
>
> GitHub prohibits use of their servers for excessive automated bulk activity or any activity that places undue burden on their infrastructure.
>
> See: [GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) · [GitHub Copilot Terms](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#github-copilot)
>
> **Please use this proxy responsibly to avoid account restrictions.**

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
| **� Railway** | **Recommended! One-click deploy, no local setup** | Free trial ($5 credit, ~1 month) |
| **☁️ Azure** | Long-term stability, enterprise features | Azure pricing |
| **🖥️ Local** | Personal use, requires Docker | Free |

---

## 🚂 Railway Deployment (Recommended, One-Click)

No local tools needed — just click and go. Railway offers a **$5 free trial** (~1 month).

### 1. One-Click Deploy

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/A1hy6O?referralCode=gCb16U)

After clicking the button:
1. Sign in to Railway with your GitHub account
2. Confirm `LITELLM_MASTER_KEY` (a random key is auto-generated, or customize your own)
3. Click **Deploy** and wait for it to finish (Volume, networking, etc. are pre-configured)

> **Save your `LITELLM_MASTER_KEY`** — you'll need it for client configuration.

### 2. Authenticate

Once deployed, visit your Railway URL → **Begin Authentication** → enter device code → authorize (~10 sec) → proxy is live.

### 3. Use It

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

## 🖥️ Run Locally

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

- [x] Railway OAuth credential persistence (auto Volume setup)
- [x] Railway one-click deploy template (Deploy Button)
- [ ] Validate token on startup, auto re-auth if expired
- [ ] AWS Bedrock as additional model backend
- [ ] Google Cloud Vertex AI support
- [ ] Azure OpenAI Service support
- [ ] Enhanced web admin panel (usage stats, model switching)
- [ ] Multi-user API key management
- [ ] Docker Compose one-click local deployment
- [ ] Auto-discover and update available model list

## License

MIT
