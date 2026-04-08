# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

CopilotBridge — a reverse proxy for the GitHub Copilot API, exposing it as an OpenAI and Anthropic compatible service. Enables teams to use Copilot-backed models (Claude, GPT, Gemini) through a single authenticated proxy in Claude Code, Cursor, custom scripts, CI/CD, and anywhere that supports the OpenAI API.

**Warning:** This is a reverse-engineered proxy, not supported by GitHub. Excessive automated use may trigger GitHub's abuse detection systems.

## Deployment Options

Three deployment methods:
- **Local Docker** — Fastest start, personal use (always free)
- **Railway** — No local Docker needed, $5 free trial (~1 month)
- **Azure Container Apps** — Long-term stability, enterprise features (Azure pricing)

## Repository Structure

```
config.env.example      — Template for deployment configuration (copy to config.env)
litellm_config.yaml     — LiteLLM model routing config (deployed to Azure/Railway)
scripts/
  _common.sh            — Shared helpers, colors, config loading, Azure utilities
  setup-auth.sh         — Phase 1+2: Local Docker auth + credential export
  deploy-azure.sh       — Phase 3+4: Provision Azure infra + deploy Container App
  configure-client.sh   — Phase 5: Print client env vars for developers/CI
  reauth.sh             — Maintenance: Re-authenticate expired GitHub OAuth token
  update.sh             — Maintenance: Update config or container image
  status.sh             — Diagnostics: Health check, logs, test completion
railway/
  Dockerfile            — Railway container image
  entrypoint.sh         — Auto-switches between Auth Wizard and LiteLLM proxy
  auth_wizard.py        — Web-based GitHub OAuth authentication UI
copilot-litellm-azure-deployment.md — Full manual deployment guide
README.md (CN) / README_EN.md — User-facing documentation
```

## Quick Start Commands

**Local Docker:**
```bash
# Start proxy (triggers GitHub auth on first run)
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

**Azure (automated):**
```bash
cp config.env.example config.env    # customize settings
./scripts/setup-auth.sh             # Docker + browser GitHub auth
./scripts/deploy-azure.sh           # provision Azure + deploy
./scripts/configure-client.sh       # get env vars for clients
./scripts/status.sh                 # verify deployment
```

**Test the proxy:**
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Architecture

**Three-layer token system:**
1. **Layer 1** — GitHub OAuth access token (long-lived, created once via Device Code Flow, persisted in Azure File Share or Railway Volume)
2. **Layer 2** — Copilot API key (short-lived, auto-refreshed by LiteLLM every ~30 min)
3. **Layer 3** — `LITELLM_MASTER_KEY` (proxy access key shared with all clients, never expires until rotated)

**Core infrastructure:**
- **Local:** Docker + volume persistence
- **Railway:** Container + Volume mount at `/root/.config/litellm`
- **Azure:** Container Apps + Azure Files (SMB share) + optional PostgreSQL (for admin UI)

**Railway entrypoint flow:**
1. Check if GitHub OAuth token exists and is valid
2. If yes → start LiteLLM proxy
3. If no/invalid → start Auth Wizard web UI for GitHub Device Flow authentication
4. After authentication → store token → container restarts → proxy starts

## Available Models

The proxy exposes these models from GitHub Copilot (configured in `litellm_config.yaml`):
- **Anthropic:** claude-sonnet-4/4.5/4.6, claude-opus-4.5/4.6/4.6-1m, claude-haiku-4.5
- **OpenAI:** gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4
- **Google:** gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview
- **Other:** minimax-m2.5

All models use the `github_copilot/` prefix in LiteLLM config but are exposed without prefix to clients.

## Conventions

**Scripts:**
- All scripts source `scripts/_common.sh` for shared functions (`log_info`, `log_ok`, `require_cmd`, `get_storage_key`, etc.)
- All scripts source `config.env` via the `load_config` function — never hardcode Azure resource names
- Scripts use `set -euo pipefail` and exit on errors
- Azure CLI output is suppressed (`--output none`) during normal operations to keep output clean
- Destructive operations (volume removal, re-auth) require interactive confirmation via the `confirm` helper

**Configuration:**
- The API key is auto-generated and stored in `.litellm_api_key` (gitignored)
- Auth credentials are exported to `.auth-export/` and `.auth-extracted/` (both gitignored)
- `config.env` is gitignored (copy from `config.env.example` to customize)

**Railway:**
- Uses `/root/.config/litellm` as the required mount path (defined in `railway.json`)
- Token stored at `/root/.config/litellm/github_copilot/access-token`
- Optional `GITHUB_COPILOT_TOKEN` env var can inject pre-exported token

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

## Maintenance

**Re-authenticate (if token expires/revoked):**
```bash
./scripts/reauth.sh                 # Azure deployment
curl -X POST https://your-proxy-url/auth/reset -H "Authorization: Bearer YOUR_MASTER_KEY"  # Railway
```

**Update configuration or image:**
```bash
./scripts/update.sh                 # Azure deployment
```

**Check deployment status:**
```bash
./scripts/status.sh                 # Azure deployment
```
