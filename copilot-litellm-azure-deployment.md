# Deploy GitHub Copilot LiteLLM Proxy on Azure Container Apps

Deploy a shared LiteLLM proxy on Azure Container Apps so that team members and CI/CD pipelines can use GitHub Copilot-backed models (Claude, GPT, Gemini) **without requiring Docker or browser authentication on each machine**.

## Architecture

```
┌──────────────────────┐
│  Developer Machine   │
│  ANTHROPIC_BASE_URL  │──┐
│  = https://proxy-url │  │
└──────────────────────┘  │     ┌───────────────────────────────┐     ┌──────────────────┐
                          ├────▶│  Azure Container Apps         │────▶│  GitHub Copilot   │
┌──────────────────────┐  │     │                               │     │  API              │
│  CI/CD Agent         │  │     │  LiteLLM Proxy                │     │                  │
│  ANTHROPIC_BASE_URL  │──┘     │  (authenticated, shared)      │     │  Claude, GPT,    │
│  = https://proxy-url │        │  :4000                        │     │  Gemini, etc.    │
└──────────────────────┘        └───────────────────────────────┘     └──────────────────┘
                                        │
                                        ▼
                                ┌───────────────────┐
                                │  Admin Dashboard   │
                                │  /ui  (Master Key) │
                                │  Logs, Usage, etc. │
                                └───────────────────┘
```

**Key benefit:** GitHub OAuth authentication is done **once** during initial setup. All clients share the authenticated proxy instance.

---

## Prerequisites

### Tools Required

| Tool | Purpose | Install |
|------|---------|---------|
| Azure CLI (`az`) | Azure resource management | [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Docker | Local auth + credential export | [Docker Desktop](https://www.docker.com/products/docker-desktop/) |
| GitHub CLI (`gh`) | Verify GitHub access | `brew install gh` or [docs](https://cli.github.com/) |

### Azure Requirements

- An Azure subscription with permissions to create Container Apps
- A resource group (or permission to create one)
- The `az containerapp` extension installed:

```bash
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

### GitHub Requirements

- A GitHub account with **GitHub Copilot** access
- The account must be able to authenticate via GitHub Device Flow

---

## Phase 1: Local Authentication (One-Time)

Run LiteLLM locally with Docker to perform the GitHub Device Flow authentication.

### 1.1 Prepare a Minimal Bootstrap Config

For the initial authentication, you only need a minimal `litellm_config.yaml` — even a single model will do, since the goal is to complete the GitHub Device Flow and obtain OAuth credentials. You will update this file with the full model list after Phase 2.

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: github_copilot/gpt-4o

general_settings:
  drop_params: true
```

> You will update this file with the full model list after discovering which models your account supports (see Phase 2).

### 1.2 Run LiteLLM Locally with Docker

**Linux / macOS:**

```bash
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

**Windows (PowerShell):**

```powershell
# MSYS_NO_PATHCONV prevents Git Bash/MSYS from mangling Linux paths in volume mounts
$env:MSYS_NO_PATHCONV=1
docker run -it --rm `
    -p 4000:4000 `
    -v "litellm_config:/root/.config" `
    -v "${PWD}\litellm_config.yaml:/app/config.yaml:ro" `
    ghcr.io/berriai/litellm:main-latest `
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

> **Windows note:** Always quote volume mount paths (`"..."`) and use `$PWD\` instead of `$(pwd)/`. Setting `$env:MSYS_NO_PATHCONV=1` is critical if Docker Desktop uses the WSL backend with MSYS path translation.

During startup:
1. LiteLLM starts and attempts to authenticate with GitHub Copilot
2. Since no credentials exist yet, it triggers the **GitHub Device Code Flow**
3. A device code and URL are printed in the terminal, for example:
   ```
   Please visit https://github.com/login/device and enter code ABCD-1234 to authenticate.
   ```
4. Open the URL in a browser and enter the device code
5. Authorize the application with your GitHub account
6. Wait for LiteLLM to log `Application startup complete`

> **Important:** If the Docker volume already has stale credentials from a previous run, LiteLLM will try to refresh them instead of showing a new device code. In that case, delete the volume first and re-run:
> ```bash
> docker volume rm litellm_config
> ```

**Keep the container running** — you will need it for the next phase.

> **Note:** The authentication credentials are stored in the Docker volume `litellm_config` at path `litellm/github_copilot/`. Two key files are created:
> - `access-token` — the GitHub OAuth access token (Layer 1)
> - `api-key.json` — the Copilot API session key (Layer 2, auto-refreshed)

---

## Phase 2: Discover Available Models

Different GitHub accounts and Copilot plans have access to different models. After authentication, you should **query the Copilot API** to discover which models are available to your account, then update `litellm_config.yaml` accordingly.

### 2.1 Query the Copilot API for Supported Models

The Copilot API key file (`api-key.json`) stored in the Docker volume contains a short-lived token and the API endpoint. Extract them and query the models endpoint:

```bash
# Extract the API endpoint and token from the Docker volume
API_KEY_JSON=$(docker run --rm \
    -v litellm_config:/source:ro \
    alpine cat /source/litellm/github_copilot/api-key.json)

API_ENDPOINT=$(echo "$API_KEY_JSON" | jq -r '.endpoints.api')
API_TOKEN=$(echo "$API_KEY_JSON" | jq -r '.token')

# Query available models
curl -s "${API_ENDPOINT}/models" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "editor-version: vscode/1.85.1" \
    -H "editor-plugin-version: copilot/1.155.0" \
    -H "Copilot-Integration-Id: vscode-chat" \
    -H "user-agent: GithubCopilot/1.155.0" \
    | jq -r '.data[].id' | sort
```

**Example output** (your list may vary based on your Copilot plan):

```
claude-haiku-4.5
claude-opus-4.5
claude-opus-4.6
claude-opus-4.6-1m
claude-sonnet-4
claude-sonnet-4.5
claude-sonnet-4.6
gemini-2.5-pro
gemini-3-flash-preview
gemini-3.1-pro-preview
gpt-4.1
gpt-4o
gpt-5-mini
gpt-5.1
gpt-5.2
gpt-5.2-codex
gpt-5.3-codex
gpt-5.4
gpt-5.4-mini
minimax-m2.5
text-embedding-3-small
...
```

> **Note:** The `api-key.json` token expires every ~30 minutes but is auto-refreshed while the container is running. If the query fails with a 401, the LiteLLM container needs to be running so it can refresh the token. You can also just restart the container and try again.

**PowerShell alternative** (Windows):

```powershell
# Save API key JSON to temp file
docker run --rm -v "litellm_config:/source:ro" alpine cat /source/litellm/github_copilot/api-key.json > .api-key-temp.json

# Query available models
$json = Get-Content ".api-key-temp.json" | ConvertFrom-Json
$ep = $json.endpoints.api
$tk = $json.token
$resp = Invoke-RestMethod -Uri "$ep/models" -Headers @{
    "Authorization" = "Bearer $tk"
    "editor-version" = "vscode/1.85.1"
    "editor-plugin-version" = "copilot/1.155.0"
    "Copilot-Integration-Id" = "vscode-chat"
    "user-agent" = "GithubCopilot/1.155.0"
}
$resp.data.id | Sort-Object

# Clean up
Remove-Item ".api-key-temp.json"
```

### 2.2 Update litellm_config.yaml

Based on the query results, update `litellm_config.yaml` to include the models you want to expose. The `model_name` is the alias clients will use, and `litellm_params.model` must be `github_copilot/<copilot-model-id>`:

```yaml
model_list:
  # --- Anthropic Claude ---
  - model_name: claude-sonnet-4.5
    litellm_params:
      model: github_copilot/claude-sonnet-4.5
  - model_name: claude-sonnet-4.6
    litellm_params:
      model: github_copilot/claude-sonnet-4.6
  - model_name: claude-opus-4.5
    litellm_params:
      model: github_copilot/claude-opus-4.5
  - model_name: claude-opus-4.6
    litellm_params:
      model: github_copilot/claude-opus-4.6
  - model_name: claude-opus-4.6-1m
    litellm_params:
      model: github_copilot/claude-opus-4.6-1m
  - model_name: claude-haiku-4.5
    litellm_params:
      model: github_copilot/claude-haiku-4.5
  - model_name: claude-sonnet-4
    litellm_params:
      model: github_copilot/claude-sonnet-4
  # --- OpenAI GPT ---
  - model_name: gpt-4o
    litellm_params:
      model: github_copilot/gpt-4o
  - model_name: gpt-4.1
    litellm_params:
      model: github_copilot/gpt-4.1
  - model_name: gpt-5-mini
    litellm_params:
      model: github_copilot/gpt-5-mini
  - model_name: gpt-5.1
    litellm_params:
      model: github_copilot/gpt-5.1
  - model_name: gpt-5.2
    litellm_params:
      model: github_copilot/gpt-5.2
  - model_name: gpt-5.4
    litellm_params:
      model: github_copilot/gpt-5.4
  # --- Google Gemini ---
  - model_name: gemini-2.5-pro
    litellm_params:
      model: github_copilot/gemini-2.5-pro
  - model_name: gemini-3-flash-preview
    litellm_params:
      model: github_copilot/gemini-3-flash-preview
  - model_name: gemini-3.1-pro-preview
    litellm_params:
      model: github_copilot/gemini-3.1-pro-preview
  # --- Other ---
  - model_name: minimax-m2.5
    litellm_params:
      model: github_copilot/minimax-m2.5

general_settings:
  drop_params: true
```

> **Pitfall:** GitHub Copilot model IDs change over time as models are retired and replaced. For example, `o3` was retired in late 2025, and `claude-sonnet-4-5` (with hyphens) is not valid — the correct ID is `claude-sonnet-4.5` (with a dot). Always use the IDs returned by the API query, not guesses based on documentation.

> **Pitfall:** Some models (e.g., `gpt-5.2-codex`, `gpt-5.3-codex`, `gpt-5.4-mini`) do **not** support the `/chat/completions` endpoint — they are code completion models only and will return a 400 error: `"model is not accessible via the /chat/completions endpoint"`. Do not include these in your config unless you specifically need the completions API.

### 2.3 Verify Models via the Local Proxy

With the LiteLLM container still running, stop and restart it with the updated config, then send test requests to confirm each model works:

```bash
# Restart with updated config
docker stop $(docker ps -q)
docker run -d --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000

# Wait a few seconds for startup
sleep 8

# Test each model
for model in claude-sonnet-4.5 gpt-4o gemini-2.5-pro; do
    echo -n "Testing $model... "
    RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}], \"max_tokens\": 5}")
    if echo "$RESPONSE" | jq -e '.choices[0].message.content' &>/dev/null; then
        echo "OK: $(echo $RESPONSE | jq -r '.choices[0].message.content')"
    else
        echo "FAIL: $(echo $RESPONSE | jq -r '.error.message' 2>/dev/null || echo $RESPONSE)"
    fi
done
```

If a model returns `"The requested model is not supported"`, remove it from your config — the model ID may be incorrect or not available on your plan.

---

## Phase 3: Export Authentication Credentials

Export the OAuth credentials from the Docker volume for Azure deployment.

**Linux / macOS:**

```bash
# Create directories
mkdir -p .auth-export .auth-extracted

# Export the entire config volume
docker run --rm \
    -v litellm_config:/source:ro \
    -v $(pwd)/.auth-export:/backup \
    alpine tar czf /backup/litellm_auth.tar.gz -C /source .

# Extract for upload
tar xzf .auth-export/litellm_auth.tar.gz -C .auth-extracted

# Verify credentials exist
find .auth-extracted -type f
```

**Windows (PowerShell):**

```powershell
# Create directories
New-Item -ItemType Directory -Path ".auth-export", ".auth-extracted" -Force | Out-Null

# Export the entire config volume
$env:MSYS_NO_PATHCONV=1
docker run --rm `
    -v "litellm_config:/source:ro" `
    -v "${PWD}\.auth-export:/backup" `
    alpine tar czf /backup/litellm_auth.tar.gz -C /source .

# Extract for upload (using alpine since Windows lacks tar with gz)
docker run --rm `
    -v "${PWD}\.auth-export:/backup:ro" `
    -v "${PWD}\.auth-extracted:/out" `
    alpine sh -c "tar xzf /backup/litellm_auth.tar.gz -C /out"

# Verify credentials exist
docker run --rm -v "litellm_config:/source:ro" alpine find /source -type f
```

Expected output:
```
/source/litellm/github_copilot/access-token
/source/litellm/github_copilot/api-key.json
```

> **Security:** These credentials grant access to the GitHub Copilot API under your account. Treat them as secrets. The `.auth-export/` and `.auth-extracted/` directories are gitignored by default.

---

## Phase 4: Prepare Azure Resources

### 4.1 Set Environment Variables

```bash
# Customize these values for your deployment
RESOURCE_GROUP="rg-litellm-proxy"
LOCATION="eastus"                            # Choose a region close to your team
CONTAINER_APP_NAME="litellm-proxy"
CONTAINER_APP_ENV="litellm-env"
STORAGE_ACCOUNT_NAME="stlitellmproxy"        # Must be globally unique, lowercase
FILE_SHARE_NAME="litellm-config"
LITELLM_API_KEY="sk-$(openssl rand -hex 16)" # Generate a shared API key

echo "Generated LITELLM_API_KEY: $LITELLM_API_KEY"
echo "Save this key! Clients will need it to connect."
```

### 4.2 Create Resource Group

```bash
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"
```

### 4.3 Create Container Apps Environment

```bash
az containerapp env create \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION"
```

### 4.4 Create Azure File Share for Credentials

The GitHub OAuth credentials need to persist across container restarts. Azure Files provides this.

```bash
# Create storage account
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query '[0].value' -o tsv)

# Create file share
az storage share create \
    --name "$FILE_SHARE_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY"
```

### 4.5 Upload Authentication Credentials

```bash
# Upload to Azure File Share
az storage file upload-batch \
    --destination "$FILE_SHARE_NAME" \
    --source .auth-extracted \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY"

# Verify upload
az storage file list \
    --share-name "$FILE_SHARE_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --output table
```

### 4.6 Upload Configuration Files

```bash
# Create a config directory in the file share
az storage directory create \
    --share-name "$FILE_SHARE_NAME" \
    --name "app-config" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY"

# Upload litellm_config.yaml
az storage file upload \
    --share-name "$FILE_SHARE_NAME" \
    --source "litellm_config.yaml" \
    --path "app-config/config.yaml" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY"

# Upload any custom hooks or patches if you have them
# az storage file upload \
#     --share-name "$FILE_SHARE_NAME" \
#     --source "my_hooks.py" \
#     --path "app-config/my_hooks.py" \
#     --account-name "$STORAGE_ACCOUNT_NAME" \
#     --account-key "$STORAGE_KEY"
```

### 4.7 Add Storage Mount to Container Apps Environment

```bash
az containerapp env storage set \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --storage-name "litellmconfig" \
    --azure-file-account-name "$STORAGE_ACCOUNT_NAME" \
    --azure-file-account-key "$STORAGE_KEY" \
    --azure-file-share-name "$FILE_SHARE_NAME" \
    --access-mode ReadWrite
```

### 4.8 (Optional) Create PostgreSQL Database for Admin UI

The LiteLLM admin dashboard (`/ui`) requires a PostgreSQL database for key management, usage tracking, and team features. **If you only need the proxy API and don't need the web dashboard, skip this step.**

| With PostgreSQL | Without PostgreSQL |
|---|---|
| Admin dashboard `/ui` works | Dashboard shows "Not connected to DB" |
| Can create/manage API keys via UI | Use `LITELLM_MASTER_KEY` for all clients |
| Usage tracking & spend analytics | No usage tracking |
| ~$13/month extra cost (B1ms) | No extra cost |

> **Note:** Some Azure regions restrict PostgreSQL Flexible Server provisioning. If you get `"The location is restricted"`, try a different region (e.g., `centralus`, `westeurope`). Cross-region DB access adds ~10-20ms latency which is negligible for admin operations.

```bash
# Generate a strong password
PG_PASSWORD="$(openssl rand -base64 24)"
echo "PG_PASSWORD: $PG_PASSWORD"    # Save this!

# Create PostgreSQL Flexible Server (Burstable B1ms, ~$13/month)
PG_LOCATION="centralus"             # May need a different region than your Container App
az postgres flexible-server create \
    --name "${CONTAINER_APP_NAME}-pg" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$PG_LOCATION" \
    --sku-name "Standard_B1ms" \
    --tier "Burstable" \
    --storage-size 32 \
    --version 16 \
    --admin-user "litellmadmin" \
    --admin-password "$PG_PASSWORD" \
    --public-access "None" \
    --yes

# Enable public access and allow Azure services
az postgres flexible-server update \
    --name "${CONTAINER_APP_NAME}-pg" \
    --resource-group "$RESOURCE_GROUP" \
    --public-access "Enabled"

az postgres flexible-server firewall-rule create \
    --name "${CONTAINER_APP_NAME}-pg" \
    --resource-group "$RESOURCE_GROUP" \
    --rule-name "AllowAzureServices" \
    --start-ip-address "0.0.0.0" \
    --end-ip-address "0.0.0.0"

# Create the litellm database
az postgres flexible-server db create \
    --server-name "${CONTAINER_APP_NAME}-pg" \
    --resource-group "$RESOURCE_GROUP" \
    --database-name "litellm"

# Build connection string
PG_HOST="${CONTAINER_APP_NAME}-pg.postgres.database.azure.com"
DATABASE_URL="postgresql://litellmadmin:${PG_PASSWORD}@${PG_HOST}:5432/litellm?sslmode=require"
echo "DATABASE_URL: $DATABASE_URL"
```

---

## Phase 5: Deploy to Azure Container Apps

Deployment is a **two-step process**: first create the app without volume mounts, then update it via YAML to add mounts and the startup command. This is necessary because `az containerapp create --command --args` has parsing issues on Windows/PowerShell.

### 5.1 Create the Container App (Basic)

**Without PostgreSQL** (no Admin UI):

```bash
az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --image "ghcr.io/berriai/litellm:main-latest" \
    --target-port 4000 \
    --ingress external \
    --transport http \
    --min-replicas 1 \
    --max-replicas 1 \
    --cpu 1.0 \
    --memory 2.0Gi \
    --env-vars \
        "LITELLM_MASTER_KEY=$LITELLM_API_KEY" \
        "PYTHONPATH=/app" \
    --output none
```

**With PostgreSQL** (enables Admin UI at `/ui`):

```bash
az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --image "ghcr.io/berriai/litellm:main-latest" \
    --target-port 4000 \
    --ingress external \
    --transport http \
    --min-replicas 1 \
    --max-replicas 1 \
    --cpu 1.0 \
    --memory 2.0Gi \
    --env-vars \
        "LITELLM_MASTER_KEY=$LITELLM_API_KEY" \
        "PYTHONPATH=/app" \
        "DATABASE_URL=$DATABASE_URL" \
        "STORE_MODEL_IN_DB=False" \
        "LITELLM_SALT_KEY=sk-litellm-salt-$(openssl rand -hex 8)" \
        "UI_USERNAME=admin" \
        "UI_PASSWORD=$LITELLM_API_KEY" \
    --output none
```

This creates a basic container without volume mounts or custom startup command. You should see output like:
```
Container app created. Access your app at https://litellm-proxy.<random>.eastus.azurecontainerapps.io/
```

### 5.2 Add Volume Mounts and Startup Command

Export the current YAML config, edit it, then re-apply:

```bash
# Export current config
az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output yaml > containerapp.yaml
```

Edit `containerapp.yaml` — find the `template.containers` section and add `command`, `volumeMounts`, and `volumes`:

```yaml
  template:
    containers:
    - env:
      - name: LITELLM_MASTER_KEY
        value: <your-key>
      - name: PYTHONPATH
        value: /app
      # >>> ONLY if you set up PostgreSQL in 4.8 <<<
      # - name: DATABASE_URL
      #   value: <your-postgresql-connection-string>
      # - name: STORE_MODEL_IN_DB
      #   value: "False"
      # - name: LITELLM_SALT_KEY
      #   value: <your-salt-key>
      # - name: UI_USERNAME
      #   value: admin
      # - name: UI_PASSWORD
      #   value: <your-key>
      # >>> ADD THIS: startup command <<<
      command:
      - sh
      - -c
      - litellm --config /mnt/config/app-config/config.yaml --host 0.0.0.0 --port 4000
      image: ghcr.io/berriai/litellm:main-latest
      imageType: ContainerImage
      name: litellm-proxy
      resources:
        cpu: 1.0
        ephemeralStorage: 4Gi
        memory: 2Gi
      # >>> ADD THIS: volume mounts <<<
      volumeMounts:
      - volumeName: litellm-storage
        mountPath: /mnt/config
      - volumeName: litellm-storage
        mountPath: /root/.config
    # ... scale section stays the same ...
    # >>> REPLACE volumes: null WITH THIS <<<
    volumes:
    - name: litellm-storage
      storageName: litellmconfig
      storageType: AzureFile
```

Apply the updated configuration:

```bash
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yaml containerapp.yaml
```

> **Note:** The two volume mounts serve different purposes:
> - `/mnt/config` — maps the file share root for accessing `app-config/config.yaml`
> - `/root/.config` — maps credentials at the path LiteLLM expects (`litellm/github_copilot/access-token`)

### 5.3 Verify Deployment

```bash
# Get the app URL
APP_URL=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" -o tsv)

echo "Proxy URL: https://$APP_URL"

# Test health endpoint (returns 401 with auth error message — this is EXPECTED)
# It means LiteLLM is running and LITELLM_MASTER_KEY is enforced
curl -s "https://$APP_URL/health"

# Test a completion (the real verification)
curl -s "https://$APP_URL/v1/chat/completions" \
    -H "Authorization: Bearer $LITELLM_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "claude-sonnet-4.5",
        "messages": [{"role": "user", "content": "Say hello in one word."}],
        "max_tokens": 10
    }' | jq .
```

> **Note:** When `LITELLM_MASTER_KEY` is set, even the `/health` endpoint returns `401 Authentication Error` for unauthenticated requests. This is correct behavior — it confirms the proxy is secured. Use an authenticated request to verify full functionality.

### 5.4 Clean Up Local Artifacts

After successful deployment, clean up temporary files:

```bash
# Remove exported credentials (they're now in Azure)
rm -rf .auth-export .auth-extracted

# Remove generated YAML
rm -f containerapp.yaml

# (Optional) Stop local Docker container if still running
docker stop $(docker ps -q --filter ancestor=ghcr.io/berriai/litellm:main-latest)
```

**Keep the following files** — they're needed for maintenance:
- `config.env` — deployment configuration
- `.litellm_api_key` — the proxy API key (also set as `LITELLM_MASTER_KEY` on the container)
- `litellm_config.yaml` — model configuration (re-upload when updating models)

---

## Phase 6: Configure Clients

Each developer sets environment variables. They do **NOT** need Docker or browser auth.

### For Claude Code Users

```bash
# Add to ~/.bashrc, ~/.zshrc, or PowerShell $PROFILE
export ANTHROPIC_BASE_URL="https://<your-app>.azurecontainerapps.io"
export ANTHROPIC_AUTH_TOKEN="<your-litellm-api-key>"
export ANTHROPIC_API_KEY="<your-litellm-api-key>"
```

**PowerShell (Windows):**

```powershell
# Add to your PowerShell profile ($PROFILE)
$env:ANTHROPIC_BASE_URL = "https://<your-app>.azurecontainerapps.io"
$env:ANTHROPIC_AUTH_TOKEN = "<your-litellm-api-key>"
$env:ANTHROPIC_API_KEY = "<your-litellm-api-key>"
```

> **Why two key variables?** Some tools use `ANTHROPIC_AUTH_TOKEN` for interactive mode and `ANTHROPIC_API_KEY` for non-interactive/print mode. Set both to the same value.

### For OpenAI-Compatible Clients

The proxy is fully OpenAI-compatible. Any tool that supports a custom OpenAI endpoint works:

```bash
export OPENAI_API_BASE="https://<your-app>.azurecontainerapps.io/v1"
export OPENAI_API_KEY="<your-litellm-api-key>"
```

### Verify Connection

```bash
claude -p "Say hello in one word."
# Should return a response without authentication errors
```

### Available Models

After deployment, these models are available through the proxy:

| Provider | Models |
|----------|--------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **Other** | minimax-m2.5 |

---

## Phase 7: CI/CD Integration

### GitHub Actions Example

```yaml
jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Claude Code
        run: curl -fsSL https://claude.ai/install.sh | sh

      - name: Run Claude Code
        env:
          ANTHROPIC_BASE_URL: ${{ secrets.LITELLM_PROXY_URL }}
          ANTHROPIC_AUTH_TOKEN: ${{ secrets.LITELLM_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.LITELLM_API_KEY }}
        run: |
          claude -p "Review the code changes" --output-format text
```

### Generic CI/CD

For any CI/CD system, set these environment variables in your pipeline secrets:

| Variable | Value | Secret? |
|----------|-------|---------|
| `ANTHROPIC_BASE_URL` | `https://<your-app>.azurecontainerapps.io` | No |
| `ANTHROPIC_AUTH_TOKEN` | `<your-litellm-api-key>` | **Yes** |
| `ANTHROPIC_API_KEY` | `<your-litellm-api-key>` (same value) | **Yes** |

---

## Token Architecture

LiteLLM uses a **three-layer token system** to authenticate with the GitHub Copilot API.

```
Layer 1: GitHub OAuth Access Token (long-lived)
  ├── Created by: GitHub Device Code Flow during local setup
  ├── Stored at:  Azure File Share → litellm/github_copilot/access-token
  ├── Expires:    Only when user revokes OAuth or org policy changes
  └── Refresh:    Manual — re-run local auth, re-upload to Azure

Layer 2: Copilot API Key (short-lived, auto-refreshed)
  ├── Created by: LiteLLM at runtime using Layer 1 token
  ├── Stored at:  Azure File Share → litellm/github_copilot/api-key.json
  ├── Expires:    Every ~30 minutes
  └── Refresh:    Automatic — LiteLLM refreshes on startup and periodically

Layer 3: LiteLLM Proxy API Key (LITELLM_MASTER_KEY)
  ├── Created by: You, during setup (stored in .litellm_api_key)
  ├── Expires:    Never (until manually rotated)
  ├── Shared with: All clients connecting to the proxy
  └── Also used:  Admin dashboard login at /ui
```

**Key takeaway:** Layer 2 is fully automatic. The only maintenance task is re-authenticating Layer 1 when it expires.

---

## Maintenance

### Re-Authentication (When GitHub OAuth Token Expires)

**Symptoms:** Clients get authentication errors but the proxy itself is reachable. Container logs show `"API key expired"`, `"Failed to refresh API key"`, or `"HTTP error refreshing API key: 401"`.

```bash
# 1. Re-authenticate locally (requires Docker + browser)
docker volume rm litellm_config
# Re-run the local Docker setup from Phase 1, then repeat Phase 2 to verify models

# 2. Export fresh credentials (Phase 3)
rm -rf .auth-export .auth-extracted
mkdir -p .auth-export .auth-extracted
docker run --rm -v litellm_config:/source:ro -v $(pwd)/.auth-export:/backup \
    alpine tar czf /backup/litellm_auth.tar.gz -C /source .
tar xzf .auth-export/litellm_auth.tar.gz -C .auth-extracted

# 3. Upload to Azure (overwrite old credentials)
STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" \
    --query "[0].value" -o tsv)
az storage file upload-batch \
    --destination "$FILE_SHARE_NAME" --source .auth-extracted \
    --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" --overwrite

# 4. Restart the container
az containerapp revision restart --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --revision $(az containerapp revision list --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

# 5. Clean up
rm -rf .auth-export .auth-extracted
```

> No client-side changes are needed. The proxy URL and API key remain the same.

### Updating LiteLLM Version

```bash
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "ghcr.io/berriai/litellm:<new-tag>"
```

### Updating Configuration

```bash
# Re-upload the changed config file
az storage file upload \
    --share-name "$FILE_SHARE_NAME" \
    --source "litellm_config.yaml" \
    --path "app-config/config.yaml" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --overwrite

# Restart to pick up changes
az containerapp revision restart \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP"
```

### Monitoring

```bash
# View container logs
az containerapp logs show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --follow

# Check container status
az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.runningStatus" -o tsv
```

---

## Troubleshooting

### "Authentication failed" from the proxy

The `LITELLM_MASTER_KEY` set on the container doesn't match what the client is sending. Verify both sides match:

```bash
az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.template.containers[0].env[?name=='LITELLM_MASTER_KEY'].value" -o tsv
```

### GitHub Copilot token expired (401/403 from upstream)

```bash
az containerapp logs show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --tail 100 | grep -iE "expired|refresh|access.token|401|403"
```

If you see token errors, follow the re-authentication steps above.

### Rate limits (429 errors)

GitHub Copilot has per-user rate limits. A single authenticated user sharing the proxy among many clients may hit these. Consider:
- Reducing concurrent usage
- Authenticating multiple users and load-balancing

### Container keeps restarting

Common causes:
- **Mount path issues:** Verify the file share contains the expected files
- **Missing dependencies:** Ensure the container has network access for any pip installs
- **Out of memory:** LiteLLM needs ~1-2 GB RAM; increase `--memory` if needed

---

## Admin Dashboard (Requires Phase 4.8)

LiteLLM includes a built-in admin dashboard for monitoring and managing the proxy. **This only works if you completed Phase 4.8** (PostgreSQL setup). Without a database, the proxy API still works normally — you just won't have the web dashboard.

### Accessing the Dashboard

Open in a browser:
```
https://<your-app>.azurecontainerapps.io/ui
```

Login credentials:
- **Username:** `admin` (set via `UI_USERNAME` env var)
- **Password:** Your `LITELLM_MASTER_KEY` (set via `UI_PASSWORD` env var, same value as in `.litellm_api_key`)

> **Note:** The old `/sso/key/generate` login page is deprecated. Use `/ui/login` for the new login experience.

### Dashboard Features

| Feature | Description |
|---------|-------------|
| **Models** | View all configured models and their status |
| **Usage** | Track token usage, request counts, and costs per model |
| **Logs** | Real-time request/response logs for debugging |
| **Keys** | Create and manage API keys for team members |
| **Settings** | View and modify proxy settings |

### API-Based Admin Operations

All admin operations require the `LITELLM_MASTER_KEY` in the `Authorization` header:

```bash
# List all models
curl -s "https://$APP_URL/v1/models" \
    -H "Authorization: Bearer $LITELLM_API_KEY" | jq '.data[].id'

# Generate a new API key for a team member
curl -s -X POST "https://$APP_URL/key/generate" \
    -H "Authorization: Bearer $LITELLM_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"key_alias": "dev-alice", "max_budget": 100}' | jq .

# Check proxy health (authenticated)
curl -s "https://$APP_URL/health/readiness" \
    -H "Authorization: Bearer $LITELLM_API_KEY" | jq .
```

> **Important:** The `LITELLM_MASTER_KEY` grants full admin access (API calls + dashboard login). Only share it with administrators. For regular team members, generate individual API keys via `/key/generate` or through the dashboard.

---

## Security Recommendations

1. **Always set `LITELLM_MASTER_KEY`** — never run with open mode on a network-accessible proxy
2. **Use HTTPS only** — Container Apps provides automatic TLS
3. **Restrict network access** — use IP allowlists or deploy within a VNet:
   ```bash
   az containerapp ingress access-restriction set \
       --name "$CONTAINER_APP_NAME" \
       --resource-group "$RESOURCE_GROUP" \
       --rule-name "AllowTeamNetwork" \
       --ip-address "<your-ip-range>/24" \
       --action Allow
   ```
4. **Rotate the proxy API key periodically**
5. **Use a team/service GitHub account** rather than a personal account for the OAuth token
6. **Enable Azure Monitor** on the Container App for usage visibility
