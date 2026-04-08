# CopilotBridge

[English](README_EN.md)

GitHub Copilot API 的逆向代理，将其暴露为 OpenAI 和 Anthropic 兼容的服务。让你在 Claude Code、Cursor、自定义脚本、CI/CD 等任何支持 OpenAI API 的地方使用 Copilot 模型（Claude、GPT、Gemini）。

> [!WARNING]
> 这是一个 GitHub Copilot API 的逆向代理。**它不受 GitHub 官方支持**，可能会意外失效。使用风险自负。

> [!WARNING]
> **GitHub 安全提示：**
> 过度的自动化或脚本化使用 Copilot（包括通过自动化工具进行的快速或批量请求）可能会触发 GitHub 的[滥用检测系统](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)。
> 您可能会收到 GitHub 安全团队的警告，进一步的异常活动可能导致您的 Copilot 访问权限被暂时停用。
>
> GitHub 禁止使用其服务器进行过度的自动化批量活动或任何给其基础设施带来不当负担的活动。
>
> 相关政策：[GitHub 可接受使用政策](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) · [GitHub Copilot 条款](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#github-copilot)
>
> **请负责任地使用此代理，以避免账户受限。**

## 为什么需要 CopilotBridge？

你已经有了 GitHub Copilot 订阅，但它的能力被锁在了 VS Code 和 GitHub 的界面里。CopilotBridge 让你：

- 在 **Claude Code** 中使用 Copilot 的 Claude/GPT 模型
- 在 **Cursor**、**Continue** 等第三方 IDE 插件中调用 Copilot 模型
- 在 **自动化脚本和 CI/CD** 中集成 AI 能力
- 在 **任何设备**上通过 API 访问，无需浏览器登录
- 一次认证，**到处使用**

## 部署方式

| 方式 | 适合场景 | 成本 |
|------|---------|------|
| **� Railway** | **推荐！一键部署，无需本地环境** | 免费体验（$5 credit，约一个月）|
| **☁️ Azure** | 长期稳定，企业级特性 | 按 Azure 计费 |
| **🖥️ 本地运行** | 个人使用，需要 Docker | 免费 |

---

## 🚂 Railway 部署（推荐，一键部署）

无需安装任何本地工具，点一下就能用。Railway 有 **$5 免费额度**，供体验约一个月。

### 1. 一键部署

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/A1hy6O?referralCode=gCb16U)

点击按钮后：
1. 使用 GitHub 账号登录 Railway
2. 确认 `LITELLM_MASTER_KEY`（模板会自动生成随机密钥，也可自定义）
3. 点击 **Deploy** 等待部署完成（Volume、网络等均已自动配置）

> **记下你的 `LITELLM_MASTER_KEY`**，后续客户端配置需要用到。

### 2. GitHub Copilot 认证

部署完成后，访问你的 Railway 域名 → 点击 **Begin Authentication** → 输入设备代码 → 授权（~10 秒）→ 代理自动进入 API 模式。

### 3. 使用

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## ☁️ Azure 部署（推荐长期使用）

Azure Container Apps 支持 Volume 持久化、VNet 网络隔离等企业级特性，适合长期稳定运行。

使用 Claude Code 等 AI 工具配合 [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) 即可完成全部部署流程，也可参考 `scripts/` 目录中的自动化脚本。

---

## 🖥️ 本地运行

只需 Docker，3 步搞定：

### 1. 启动本地代理

```bash
# 第一次运行会触发 GitHub OAuth 认证
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

**Windows PowerShell：**
```powershell
$env:MSYS_NO_PATHCONV=1
docker run -it --rm `
    -p 4000:4000 `
    -v "litellm_config:/root/.config" `
    -v "${PWD}\litellm_config.yaml:/app/config.yaml:ro" `
    -e LITELLM_MASTER_KEY=sk-your-secret-key `
    ghcr.io/berriai/litellm:main-latest `
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

### 2. 完成 GitHub 认证

启动后终端会显示：
```
Please visit https://github.com/login/device and enter code XXXX-YYYY to authenticate.
```
打开链接，输入代码，授权即可。

### 3. 使用

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

> 认证信息保存在 Docker volume `litellm_config` 中，下次启动自动复用，无需重复认证。

---

## 客户端配置

**Claude Code：**
```bash
export ANTHROPIC_BASE_URL="https://your-proxy-url"
export ANTHROPIC_AUTH_TOKEN="YOUR_MASTER_KEY"
export ANTHROPIC_API_KEY="YOUR_MASTER_KEY"
```

**OpenAI 兼容客户端（Cursor、Continue 等）：**
```bash
export OPENAI_API_BASE="https://your-proxy-url/v1"
export OPENAI_API_KEY="YOUR_MASTER_KEY"
```

## 可用模型

| 提供商 | 模型 |
|--------|------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **其他** | minimax-m2.5 |

## 关于 Token 刷新

- **Copilot API 密钥**（~30 分钟过期）：LiteLLM **自动刷新**，无需操作
- **GitHub OAuth 令牌**：长期有效，除非手动撤销授权

通常**不需要重新认证**。如需手动触发：
```bash
curl -X POST https://your-proxy-url/auth/reset \
  -H "Authorization: Bearer YOUR_MASTER_KEY"
```

## 架构

```
你的工具（Claude Code / Cursor / 脚本 / CI）
    │
    ▼
┌─────────────────────────┐
│  CopilotBridge 代理     │
│  本地 / Railway / Azure │
└────────────┬────────────┘
             │ 自动管理的 OAuth
             ▼
┌─────────────────────────┐
│  GitHub Copilot API     │
│  Claude, GPT, Gemini    │
└─────────────────────────┘
```

## Roadmap

- [x] Railway OAuth 凭据持久化（Volume 自动配置）
- [x] Railway 一键部署模板（Deploy Button）
- [ ] 启动时自动检测 Token 有效性，失效自动进入重新认证
- [ ] 支持 AWS Bedrock 作为额外的模型后端
- [ ] 支持 Google Cloud Vertex AI
- [ ] 支持 Azure OpenAI Service
- [ ] Web 管理面板增强（用量统计、模型切换）
- [ ] 多用户 API Key 管理
- [ ] Docker Compose 一键本地部署
- [ ] 自动发现并更新可用模型列表

## 许可证

MIT
