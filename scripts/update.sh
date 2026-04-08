#!/usr/bin/env bash
# Update LiteLLM configuration or container image on Azure.
#
# Usage:
#   ./scripts/update.sh config    — re-upload litellm_config.yaml and restart
#   ./scripts/update.sh image TAG — update the container image to a new tag
#   ./scripts/update.sh image     — update to the image specified in config.env

set -euo pipefail
source "$(dirname "$0")/_common.sh"
load_config

require_cmd az "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
require_az_login

ACTION="${1:-}"

usage() {
    echo "Usage: $0 {config|image [TAG]}"
    echo ""
    echo "  config         Re-upload litellm_config.yaml and restart the container"
    echo "  image [TAG]    Update container image (default: image from config.env)"
    exit 1
}

restart_container() {
    log_info "Restarting Container App..."
    REVISION=$(az containerapp revision list \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[0].name" -o tsv)
    az containerapp revision restart \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --revision "$REVISION" \
        --output none
    log_ok "Container restarting. Run ./scripts/status.sh to verify."
}

case "$ACTION" in
    config)
        log_info "=== Update Configuration ==="
        STORAGE_KEY=$(get_storage_key)

        log_info "Uploading litellm_config.yaml..."
        az storage file upload \
            --share-name "$FILE_SHARE_NAME" \
            --source "${REPO_ROOT}/litellm_config.yaml" \
            --path "app-config/config.yaml" \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --account-key "$STORAGE_KEY" \
            --overwrite \
            --output none
        log_ok "Configuration uploaded."
        restart_container
        ;;
    image)
        NEW_IMAGE="${2:-$LITELLM_IMAGE}"
        log_info "=== Update Container Image ==="
        log_info "New image: $NEW_IMAGE"

        if ! confirm "Update container image?"; then
            log_info "Aborted."
            exit 0
        fi

        az containerapp update \
            --name "$CONTAINER_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --image "$NEW_IMAGE" \
            --output none
        log_ok "Image updated to: $NEW_IMAGE"
        ;;
    *)
        usage
        ;;
esac
