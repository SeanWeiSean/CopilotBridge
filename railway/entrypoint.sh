#!/bin/sh
set -e

TOKEN_DIR="/root/.config/litellm/github_copilot"
TOKEN_FILE="${TOKEN_DIR}/access-token"

# If GITHUB_COPILOT_TOKEN env var is set and no token file exists, inject it
if [ -n "$GITHUB_COPILOT_TOKEN" ] && [ ! -f "$TOKEN_FILE" ]; then
    echo "[entrypoint] Injecting GITHUB_COPILOT_TOKEN from environment variable..."
    mkdir -p "$TOKEN_DIR"
    printf '%s' "$GITHUB_COPILOT_TOKEN" > "$TOKEN_FILE"
fi

# Mode switch: token exists → LiteLLM proxy, otherwise → Auth Wizard
if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    echo "[entrypoint] Token found. Starting LiteLLM proxy..."
    exec litellm --config /app/config.yaml --host 0.0.0.0 --port 4000
else
    echo "[entrypoint] No token found. Starting Auth Wizard..."
    exec python /app/railway/auth_wizard.py
fi
