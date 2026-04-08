#!/usr/bin/env bash
# Output client configuration instructions for connecting to the deployed proxy.

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

log_info "=== Client Configuration ==="
echo ""

require_cmd az "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
require_az_login

load_or_generate_api_key

APP_URL=$(get_app_url 2>/dev/null || true)

if [[ -z "$APP_URL" ]]; then
    log_error "Could not find Container App '$CONTAINER_APP_NAME'. Has it been deployed?"
    log_error "Run ./scripts/deploy-azure.sh first."
    exit 1
fi

PROXY_URL="https://${APP_URL}"

cat <<EOF

$(echo -e "${GREEN}Add these to your shell profile (~/.bashrc, ~/.zshrc, or ~/.profile):${NC}")

  export ANTHROPIC_BASE_URL="${PROXY_URL}"
  export ANTHROPIC_AUTH_TOKEN="${LITELLM_API_KEY}"
  export ANTHROPIC_API_KEY="${LITELLM_API_KEY}"

$(echo -e "${GREEN}Or run this one-liner to append them now:${NC}")

  cat >> ~/.bashrc << 'ENVBLOCK'
  # CopilotLiteLLM proxy
  export ANTHROPIC_BASE_URL="${PROXY_URL}"
  export ANTHROPIC_AUTH_TOKEN="${LITELLM_API_KEY}"
  export ANTHROPIC_API_KEY="${LITELLM_API_KEY}"
  ENVBLOCK

$(echo -e "${GREEN}For CI/CD pipelines, set these secrets:${NC}")

  ANTHROPIC_BASE_URL = ${PROXY_URL}
  ANTHROPIC_AUTH_TOKEN = ${LITELLM_API_KEY}  (secret)
  ANTHROPIC_API_KEY   = ${LITELLM_API_KEY}  (secret, same value)

$(echo -e "${GREEN}Quick test:${NC}")

  curl -s "${PROXY_URL}/v1/models" -H "Authorization: Bearer ${LITELLM_API_KEY}" | jq .

EOF
