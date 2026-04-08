# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [한국어](README_KO.md) | [Español](README_ES.md)

GitHub Copilot の能力をあらゆるツールとワークフローに拡張します。OpenAI 互換 API エンドポイントを通じて、Claude Code、Cursor、カスタムスクリプト、CI/CD など、OpenAI API をサポートするあらゆる場所で Copilot モデル（Claude、GPT、Gemini）を利用できます。

## なぜ CopilotBridge？

GitHub Copilot のサブスクリプションはすでにお持ちですが、その能力は VS Code と GitHub の UI に閉じ込められています。CopilotBridge を使えば：

- **Claude Code** で Copilot の Claude/GPT モデルを使用
- **Cursor**、**Continue** などのサードパーティ IDE プラグインから呼び出し
- **自動化スクリプトや CI/CD** に AI 能力を統合
- **どのデバイスからでも** API でアクセス（ブラウザログイン不要）
- 一度認証すれば、**どこでも使える**

## デプロイ方法

| 方法 | 適した用途 | コスト |
|------|-----------|--------|
| **🖥️ ローカル** | 個人利用、最速スタート | 無料 |
| **🚂 Railway** | ローカル Docker 不要、どこからでもアクセス | 無料体験（$5 クレジット、約1ヶ月）|
| **☁️ Azure** | 長期安定運用、エンタープライズ機能 | Azure 料金 |

---

## 🖥️ ローカル実行（最速スタート）

Docker さえあれば、3ステップで完了：

### 1. プロキシを起動

```bash
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

### 2. GitHub 認証

ターミナルに表示されるデバイスコードをブラウザで入力して認証。

### 3. 使用開始

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "こんにちは！"}]}'
```

---

## 🚂 Railway デプロイ（ローカル Docker 不要）

Railway には **$5 の無料クレジット**（約1ヶ月分）があります。

1. このリポを **Fork** → [railway.com](https://railway.com/) で GitHub ログイン → **Deploy from GitHub Repo**
2. 環境変数を設定：`LITELLM_MASTER_KEY`（強力な秘密鍵）、`RAILWAY_RUN_UID=0`
3. Settings → Networking → **Generate Domain**
4. Settings → Build → Custom Dockerfile Path → `railway/Dockerfile`
5. Settings → Source → **Disconnect**（自動デプロイを無効化）
6. ドメイン URL を開いて認証ウィザードを完了

> **🚨 `LITELLM_MASTER_KEY` は必ず設定してください！** 未設定の場合、**深刻な金銭的損失とアカウントリスク**が発生する可能性があります。

---

## ☁️ Azure デプロイ（長期利用推奨）

[copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) を参照。Claude Code 等の AI ツールでデプロイを完了できます。

## 利用可能なモデル

| プロバイダー | モデル |
|-------------|--------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **その他** | minimax-m2.5 |

## Roadmap

- [ ] Railway OAuth 資格情報の永続化（Volume 自動設定）
- [ ] Railway ワンクリックデプロイテンプレート
- [ ] AWS Bedrock バックエンド対応
- [ ] Google Cloud Vertex AI 対応
- [ ] Azure OpenAI Service 対応
- [ ] Web 管理パネル強化（使用量統計、モデル切替）
- [ ] マルチユーザー API キー管理
- [ ] Docker Compose ワンクリックローカルデプロイ

## ライセンス

MIT
