"""
CopilotLiteLLM Auth Wizard — Web-based GitHub Copilot OAuth setup.

Serves a single-page auth wizard on port 4000 when no GitHub Copilot
credentials exist. After successful authentication, writes the access
token to disk and exits so the container restarts into LiteLLM proxy mode.
"""

import json
import os
import sys
import time
from pathlib import Path

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse

# --- GitHub OAuth constants (from LiteLLM source) ---
GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98"
GITHUB_DEVICE_CODE_URL = "https://github.com/login/device/code"
GITHUB_ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_API_KEY_URL = "https://api.github.com/copilot_internal/v2/token"
OAUTH_SCOPE = "read:user"

# --- Paths ---
TOKEN_DIR = Path(
    os.getenv("GITHUB_COPILOT_TOKEN_DIR", "/root/.config/litellm/github_copilot")
)
ACCESS_TOKEN_FILE = TOKEN_DIR / "access-token"
TEMPLATE_PATH = Path(__file__).parent / "templates" / "setup.html"

# --- State ---
_auth_state: dict = {}

app = FastAPI(title="CopilotLiteLLM Auth Wizard")


def _github_headers() -> dict:
    return {
        "accept": "application/json",
        "editor-version": "vscode/1.85.1",
        "editor-plugin-version": "copilot/1.155.0",
        "user-agent": "GithubCopilot/1.155.0",
        "content-type": "application/json",
    }


@app.get("/", response_class=HTMLResponse)
async def index():
    """Serve the auth wizard HTML page."""
    if ACCESS_TOKEN_FILE.exists() and ACCESS_TOKEN_FILE.stat().st_size > 0:
        return HTMLResponse(
            "<html><body><h1>Proxy is ready</h1>"
            "<p>LiteLLM proxy is authenticated. Container will restart into proxy mode.</p>"
            "</body></html>"
        )
    html = TEMPLATE_PATH.read_text(encoding="utf-8")
    return HTMLResponse(html)


@app.get("/health")
async def health():
    """Health check endpoint."""
    if ACCESS_TOKEN_FILE.exists() and ACCESS_TOKEN_FILE.stat().st_size > 0:
        return {"status": "proxy_ready"}
    return {"status": "setup_required"}


@app.post("/auth/start")
async def auth_start():
    """Initiate GitHub Device Code Flow."""
    global _auth_state

    if ACCESS_TOKEN_FILE.exists() and ACCESS_TOKEN_FILE.stat().st_size > 0:
        return JSONResponse(
            {"error": "Already authenticated. Restart container to enter proxy mode."},
            status_code=400,
        )

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                GITHUB_DEVICE_CODE_URL,
                headers=_github_headers(),
                json={"client_id": GITHUB_CLIENT_ID, "scope": OAUTH_SCOPE},
            )
            resp.raise_for_status()
            data = resp.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"GitHub API error: {e}")

    required = ["device_code", "user_code", "verification_uri"]
    if not all(k in data for k in required):
        raise HTTPException(status_code=502, detail="Unexpected GitHub response")

    _auth_state = {
        "device_code": data["device_code"],
        "user_code": data["user_code"],
        "verification_uri": data["verification_uri"],
        "interval": data.get("interval", 5),
        "started_at": time.time(),
    }

    return {
        "user_code": data["user_code"],
        "verification_uri": data["verification_uri"],
    }


@app.get("/auth/poll")
async def auth_poll():
    """Poll GitHub to check if the user has completed authorization."""
    global _auth_state

    if ACCESS_TOKEN_FILE.exists() and ACCESS_TOKEN_FILE.stat().st_size > 0:
        return {"status": "authenticated"}

    if not _auth_state:
        return {"status": "not_started"}

    # 5-minute timeout
    if time.time() - _auth_state["started_at"] > 300:
        _auth_state = {}
        return {"status": "expired", "message": "Authentication timed out. Please try again."}

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                GITHUB_ACCESS_TOKEN_URL,
                headers=_github_headers(),
                json={
                    "client_id": GITHUB_CLIENT_ID,
                    "device_code": _auth_state["device_code"],
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                },
            )
            resp.raise_for_status()
            data = resp.json()
    except Exception as e:
        return {"status": "error", "message": f"Poll error: {e}"}

    if "access_token" in data:
        access_token = data["access_token"]

        # Verify token works with Copilot API
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                verify_resp = await client.get(
                    GITHUB_API_KEY_URL,
                    headers={
                        **_github_headers(),
                        "authorization": f"token {access_token}",
                    },
                )
                verify_resp.raise_for_status()
                api_key_data = verify_resp.json()
        except Exception as e:
            return {
                "status": "error",
                "message": f"Token obtained but Copilot API verification failed: {e}. "
                "Ensure your GitHub account has Copilot access.",
            }

        # Write credentials
        TOKEN_DIR.mkdir(parents=True, exist_ok=True)
        ACCESS_TOKEN_FILE.write_text(access_token)
        (TOKEN_DIR / "api-key.json").write_text(json.dumps(api_key_data))

        _auth_state = {}
        print("[auth_wizard] Authentication successful! Token saved.", flush=True)
        print("[auth_wizard] Exiting to restart into LiteLLM proxy mode...", flush=True)

        # Schedule exit after response is sent
        import asyncio
        asyncio.get_event_loop().call_later(2, _shutdown)

        return {"status": "authenticated"}

    error = data.get("error", "")
    if error == "authorization_pending":
        return {"status": "pending"}
    elif error == "slow_down":
        return {"status": "pending", "message": "Rate limited, slowing down..."}
    elif error == "expired_token":
        _auth_state = {}
        return {"status": "expired", "message": "Device code expired. Please try again."}
    elif error == "access_denied":
        _auth_state = {}
        return {"status": "denied", "message": "Authorization was denied by the user."}
    else:
        return {"status": "error", "message": f"Unexpected response: {data}"}


@app.post("/auth/reset")
async def auth_reset(request: Request):
    """Delete credentials and trigger re-auth. Requires LITELLM_MASTER_KEY."""
    auth_header = request.headers.get("authorization", "")
    master_key = os.getenv("LITELLM_MASTER_KEY", "")

    if not master_key:
        raise HTTPException(status_code=500, detail="LITELLM_MASTER_KEY not configured")

    expected = f"Bearer {master_key}"
    if auth_header != expected:
        raise HTTPException(status_code=401, detail="Invalid master key")

    # Remove credential files
    for f in [ACCESS_TOKEN_FILE, TOKEN_DIR / "api-key.json"]:
        if f.exists():
            f.unlink()

    global _auth_state
    _auth_state = {}

    print("[auth_wizard] Credentials cleared. Exiting to restart into wizard mode...", flush=True)

    import asyncio
    asyncio.get_event_loop().call_later(2, _shutdown)

    return {"status": "reset", "message": "Credentials cleared. Container will restart into setup wizard."}


def _shutdown():
    """Exit the process so Railway restarts us."""
    print("[auth_wizard] Shutting down...", flush=True)
    os._exit(0)


def main():
    print("=" * 60, flush=True)
    print("  CopilotLiteLLM Auth Wizard", flush=True)
    print("  Open your browser to complete GitHub Copilot setup.", flush=True)
    print("=" * 60, flush=True)

    uvicorn.run(app, host="0.0.0.0", port=4000, log_level="info")


if __name__ == "__main__":
    main()
