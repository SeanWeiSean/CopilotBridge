# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

CopilotLiteLLM — tooling and guides for deploying a shared LiteLLM proxy on Azure Container Apps, enabling teams to use GitHub Copilot-backed models (Claude, GPT, Gemini) through a single authenticated proxy without per-machine Docker or browser auth.

## Repository Structure

```
config.env.example      — Template for deployment configuration (copy to config.env)
litellm_config.yaml     — LiteLLM model routing config (deployed to Azure)
scripts/
  _common.sh            — Shared helpers, colors, config loading, Azure utilities
  setup-auth.sh         — Phase 1+2: Local Docker auth + credential export
  deploy-azure.sh       — Phase 3+4: Provision Azure infra + deploy Container App
  configure-client.sh   — Phase 5: Print client env vars for developers/CI
  reauth.sh             — Maintenance: Re-authenticate expired GitHub OAuth token
  update.sh             — Maintenance: Update config or container image
  status.sh             — Diagnostics: Health check, logs, test completion
copilot-litellm-azure-deployment.md — Full manual deployment guide
```

## Deployment Workflow

```
1. cp config.env.example config.env    # customize settings
2. ./scripts/setup-auth.sh             # Docker + browser GitHub auth (one-time)
3. ./scripts/deploy-azure.sh           # provision Azure + deploy (one-time)
4. ./scripts/configure-client.sh       # get env vars for developers
5. ./scripts/status.sh                 # verify everything works
```

## Architecture

The proxy uses a three-layer token system:
1. **Layer 1** — GitHub OAuth access token (long-lived, created once via Device Code Flow, stored in Azure File Share)
2. **Layer 2** — Copilot API key (short-lived, auto-refreshed by LiteLLM every ~30 min)
3. **Layer 3** — `LITELLM_MASTER_KEY` (proxy access key shared with all clients, never expires until rotated)

Core infrastructure: Azure Container Apps + Azure Files (credential persistence) + LiteLLM Docker image (`ghcr.io/berriai/litellm`).

## Conventions

- All scripts source `scripts/_common.sh` for shared functions (`log_info`, `log_ok`, `require_cmd`, `get_storage_key`, etc.)
- All scripts source `config.env` via the `load_config` function — never hardcode Azure resource names
- The API key is auto-generated and stored in `.litellm_api_key` (gitignored)
- Auth credentials are exported to `.auth-export/` and `.auth-extracted/` (both gitignored)
- Scripts use `set -euo pipefail` and exit on errors
- Azure CLI output is suppressed (`--output none`) during normal operations to keep output clean
- Destructive operations (volume removal, re-auth) require interactive confirmation via the `confirm` helper
