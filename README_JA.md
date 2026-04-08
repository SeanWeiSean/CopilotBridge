# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [한국어](README_KO.md) | [Español](README_ES.md)

GitHub Copilot のモデル（Claude、GPT、Gemini）を、単一の OpenAI 互換 API エンドポイントでチーム共有できる LiteLLM プロキシです。各マシンでの Docker セットアップやブラウザ認証は不要です。

> **デプロイ方法の選択：**
> - **Railway（お試し）**：無料トライアルクレジット（$5）があり、個人利用やテストに最適。約1ヶ月間無料で利用可能。以下のガイドに従ってください。
> - **Azure Container Apps（本番環境推奨）**：チームでの長期利用に最適。[copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) を参照してください。Claude Code などの AI ツールでデプロイを完了できます。

## Railway へのクイックデプロイ

### 1. Fork してデプロイ

1. このリポジトリを自分の GitHub アカウントに **Fork**
2. [railway.com](https://railway.com/) を開き、GitHub アカウントでログイン
3. プロンプトが表示されたら **Railway GitHub App をインストール** してリポジトリへのアクセスを許可
4. **New Project** → **Deploy from GitHub Repo** → Fork した `CopilotBridge` を選択
5. Railway が自動的にビルドを開始

### 2. 設定

初回デプロイ後（認証ウィザードが表示されます）、Railway で以下を設定：

**環境変数**（サービス → Variables タブ → New Variable）：

| 変数 | 値 |
|---|---|
| `LITELLM_MASTER_KEY` | 高強度の秘密鍵（32文字以上のランダム文字列）。パスワード生成ツールで生成してください。例：`sk-` + ランダムな32桁の16進文字列 |
| `RAILWAY_RUN_UID` | `0` |

> **🚨 `LITELLM_MASTER_KEY` は必ず設定してください！** 設定しない場合、プロキシは完全にオープンになり、インターネット上の誰でも AI モデルを呼び出せます。**深刻な金銭的損失やアカウントリスク**につながる可能性があります。

**ネットワーク設定**（サービス → Settings タブ → Networking）：

- **Public Networking** で **Generate Domain** をクリック

**Dockerfile パス**（サービス → Settings タブ → Build）：

- **Custom Dockerfile Path** を `railway/Dockerfile` に設定

**自動デプロイの無効化**（サービス → Settings タブ → Source）：

- **Branch connected to production** を見つけて **Disconnect** をクリック
- コードの push による自動再デプロイを防止します（再デプロイすると OAuth 資格情報が失われます）

### 3. GitHub Copilot 認証

1. ブラウザで Railway のドメイン URL を開く
2. **CopilotBridge 認証ウィザード** が表示される
3. **Begin Authentication** をクリック
4. デバイスコードが表示される → **Open GitHub** をクリックしてコードを入力
5. GitHub で認証（約10秒）
6. プロキシが自動的に再起動して API モードに移行

### 4. プロキシの使用

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "こんにちは！"}]}'
```

### 利用可能なモデル

| プロバイダー | モデル |
|-------------|--------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **その他** | minimax-m2.5 |

---

## Azure デプロイ

Azure Container Apps へのデプロイについては、[copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) と `scripts/` ディレクトリを参照してください。

## ライセンス

MIT
