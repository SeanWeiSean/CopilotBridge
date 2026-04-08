#!/usr/bin/env bash
# Phase 1+2: Authenticate with GitHub Copilot via LiteLLM Docker and export credentials.
# Requires: Docker (running), a browser for GitHub Device Flow.

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

log_info "=== GitHub Copilot Authentication Setup ==="
echo ""

# --- Prerequisites ---
require_docker

# --- Phase 1: Run LiteLLM locally for GitHub Device Flow auth ---
log_info "Starting LiteLLM container for GitHub authentication..."
log_info "A device code will appear below. Open the URL in a browser and enter it."
echo ""

docker run $DOCKER_IT_FLAG --rm \
    -p "${LITELLM_PORT}:${LITELLM_PORT}" \
    -v "${DOCKER_VOLUME_NAME}:/root/.config" \
    -v "${REPO_ROOT}/litellm_config.yaml:/app/config.yaml:ro" \
    "$LITELLM_IMAGE" \
    --config /app/config.yaml --host 0.0.0.0 --port "$LITELLM_PORT" || true

echo ""
log_info "Container stopped. Checking if authentication succeeded..."

# --- Phase 2: Export credentials from Docker volume ---
EXPORT_DIR="${REPO_ROOT}/.auth-export"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

log_info "Exporting credentials from Docker volume '${DOCKER_VOLUME_NAME}'..."

docker run --rm \
    -v "${DOCKER_VOLUME_NAME}:/source:ro" \
    -v "${EXPORT_DIR}:/backup" \
    alpine tar czf /backup/litellm_auth.tar.gz -C /source .

if [[ ! -f "${EXPORT_DIR}/litellm_auth.tar.gz" ]]; then
    log_error "Failed to export credentials. The Docker volume may be empty."
    log_error "Re-run this script and complete the GitHub Device Flow in the browser."
    exit 1
fi

# Verify credentials exist in the archive
CRED_FILES=$(docker run --rm \
    -v "${DOCKER_VOLUME_NAME}:/source:ro" \
    alpine find /source -type f \( -name "*.json" -o -name "*token*" -o -name "*auth*" \) 2>/dev/null || true)

if [[ -z "$CRED_FILES" ]]; then
    log_warn "No credential files found in the volume. Authentication may not have completed."
    log_warn "Re-run this script and make sure to complete the GitHub Device Flow."
    exit 1
fi

log_ok "Credentials exported to ${EXPORT_DIR}/litellm_auth.tar.gz"
echo ""
log_info "Found credential files:"
echo "$CRED_FILES" | sed 's|/source/|  |'
echo ""
log_ok "Authentication complete. Next step: run ./scripts/deploy-azure.sh"
