# CopilotBridge

[English](README_EN.md)

一个共享的 LiteLLM 代理，让团队通过单一的 OpenAI 兼容 API 端点使用 GitHub Copilot 模型（Claude、GPT、Gemini）——无需每台机器单独安装 Docker 或浏览器认证。

## 一键部署到 Railway

### 1. Fork 并部署

1. **Fork** 本仓库到你的 GitHub 账号
2. 打开 [railway.com](https://railway.com/)，使用 GitHub 账号登录
3. 如果提示，点击 **Install Railway GitHub App** 授权访问你的仓库
4. **New Project** → **Deploy from GitHub Repo** → 选择你 fork 的 `CopilotBridge` 仓库
5. Railway 会自动开始构建

### 2. 配置

首次部署完成后（会显示认证向导页面），在 Railway 中配置以下内容：

**环境变量**（服务 → Variables 标签 → New Variable）：

| 变量 | 值 |
|---|---|
| `LITELLM_MASTER_KEY` | 一个高强度密钥（至少 32 位随机字符）。可用密码生成器生成，例如：`sk-` + 随机 32 位十六进制字符串 |
| `RAILWAY_RUN_UID` | `0` |

生成密钥示例（在终端运行）：
```bash
# Linux / macOS
echo "sk-$(openssl rand -hex 16)"
# PowerShell
"sk-" + -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
```

> **🚨 强烈建议设置 `LITELLM_MASTER_KEY`！** 如果不设置此密钥，代理将完全开放——互联网上任何人都可以通过你的代理调用 AI 模型，消耗你的 GitHub Copilot 配额，可能导致**严重的资金损失和账号风险**。

**网络配置**（服务 → Settings 标签 → Networking）：

- 在 **Public Networking** 下，点击 **Generate Domain**
- 你会得到一个类似 `https://your-app-production.up.railway.app` 的 URL

**Dockerfile 路径**（服务 → Settings 标签 → Build）：

- 将 **Custom Dockerfile Path** 设置为 `railway/Dockerfile`

**关闭自动部署**（服务 → Settings 标签 → Source）：

- 找到 **Branch connected to production**，点击 **Disconnect**
- 这样 push 代码不会触发自动重新部署（重新部署会导致 OAuth 凭据丢失）
- 需要更新时，在 Railway 中手动触发：`Cmd+K` → "Deploy Latest Commit"

### 3. GitHub Copilot 认证

1. 在浏览器中打开你的 Railway 域名 URL
2. 你会看到 **CopilotBridge 认证向导**
3. 点击 **Begin Authentication**（开始认证）
4. 页面显示设备代码 —— 点击 **Open GitHub** 并输入代码
5. 在 GitHub 页面授权（约 10 秒）
6. 代理自动重启进入 API 模式

### 4. 使用代理

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "你好！"}]}'
```

**Claude Code 用户配置：**

```bash
export ANTHROPIC_BASE_URL="https://your-app.up.railway.app"
export ANTHROPIC_AUTH_TOKEN="YOUR_MASTER_KEY"
export ANTHROPIC_API_KEY="YOUR_MASTER_KEY"
```

### 可用模型

| 提供商 | 模型 |
|--------|------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **其他** | minimax-m2.5 |

### 重新认证

如果 GitHub OAuth 令牌过期，容器会自动崩溃并重启进入认证向导。再次访问 URL 完成认证即可。

手动触发重新认证：

```bash
curl -X POST https://your-app.up.railway.app/auth/reset \
  -H "Authorization: Bearer YOUR_MASTER_KEY"
```

> **提示：** 挂载 [Railway Volume](https://docs.railway.com/guides/volumes)（路径 `/root/.config`）可以在重新部署后保留 OAuth 凭据。

---

## Azure 部署

如需部署到 Azure Container Apps，请参阅 [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) 和 `scripts/` 目录。

## 架构

```
用户 / CI/CD
    │
    ▼
┌─────────────────────────┐
│  CopilotBridge 代理     │
│  (LiteLLM on Railway)   │
│  LITELLM_MASTER_KEY     │
└────────────┬────────────┘
             │ GitHub OAuth 令牌
             ▼
┌─────────────────────────┐
│  GitHub Copilot API     │
│  Claude, GPT, Gemini    │
└─────────────────────────┘
```

代理使用三层令牌机制：
- **第一层** — GitHub OAuth 访问令牌（长期有效，通过设备代码流获取）
- **第二层** — Copilot API 密钥（短期有效，LiteLLM 每 ~30 分钟自动刷新）
- **第三层** — `LITELLM_MASTER_KEY`（代理访问密钥，分享给客户端使用）

## 许可证

MIT
