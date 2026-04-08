# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

GitHub Copilot API의 리버스 프록시. OpenAI 및 Anthropic 호환 서비스로 노출하여 Claude Code, Cursor, CI/CD 등에서 Copilot 모델(Claude, GPT, Gemini)을 사용할 수 있습니다.

> [!WARNING]
> 이것은 GitHub Copilot API의 리버스 엔지니어링 프록시입니다. **GitHub의 공식 지원을 받지 않으며**, 예고 없이 작동이 중단될 수 있습니다. 사용에 따른 위험은 본인에게 있습니다.

> [!WARNING]
> **GitHub 보안 경고:**
> Copilot의 과도한 자동화 또는 스크립트 사용은 GitHub의 [남용 감지 시스템](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)을 트리거할 수 있습니다.
> 관련 정책: [GitHub 이용 약관](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) · [GitHub Copilot 조건](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#github-copilot)
>
> **계정 제한을 피하기 위해 책임감 있게 사용해 주세요.**

## 왜 CopilotBridge인가?

GitHub Copilot 구독이 있지만, 그 능력은 VS Code와 GitHub UI에 갇혀 있습니다. CopilotBridge를 사용하면:

- **Claude Code**에서 Copilot의 Claude/GPT 모델 사용
- **Cursor**, **Continue** 등 서드파티 IDE 플러그인에서 호출
- **자동화 스크립트와 CI/CD**에 AI 능력 통합
- **모든 기기**에서 API로 접근 (브라우저 로그인 불필요)
- 한 번 인증하면, **어디서나 사용**

## 배포 방법

| 방법 | 적합한 용도 | 비용 |
|------|-----------|------|
| **🖥️ 로컬** | 개인 사용, 가장 빠른 시작 | 무료 |
| **🚂 Railway** | 로컬 Docker 불필요, 어디서나 접근 | 무료 체험 ($5 크레딧, ~1개월) |
| **☁️ Azure** | 장기 안정 운영, 엔터프라이즈 기능 | Azure 요금 |

---

## 🖥️ 로컬 실행 (가장 빠른 시작)

Docker만 있으면, 3단계로 완료:

### 1. 프록시 시작

```bash
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

### 2. GitHub 인증

터미널에 표시되는 디바이스 코드를 브라우저에서 입력하여 인증.

### 3. 사용 시작

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "안녕하세요!"}]}'
```

---

## 🚂 Railway 배포 (로컬 Docker 불필요)

Railway에는 **$5 무료 크레딧**(~1개월분)이 있습니다.

1. 이 저장소를 **Fork** → [railway.com](https://railway.com/)에서 GitHub 로그인 → **Deploy from GitHub Repo**
2. 환경 변수 설정: `LITELLM_MASTER_KEY`(강력한 비밀 키), `RAILWAY_RUN_UID=0`
3. Settings → Networking → **Generate Domain**
4. Settings → Build → Custom Dockerfile Path → `railway/Dockerfile`
5. Settings → Source → **Disconnect** (자동 배포 비활성화)
6. 도메인 URL을 열어 인증 마법사 완료

> **🚨 `LITELLM_MASTER_KEY`를 반드시 설정하세요!** 미설정 시 **심각한 금전적 손실과 계정 위험**이 발생할 수 있습니다.

---

## ☁️ Azure 배포 (장기 사용 권장)

[copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md)를 참조하세요. Claude Code 등 AI 도구로 배포를 완료할 수 있습니다.

## 사용 가능한 모델

| 제공업체 | 모델 |
|----------|------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **기타** | minimax-m2.5 |

## Roadmap

- [ ] Railway OAuth 자격 증명 영구 저장 (Volume 자동 설정)
- [ ] Railway 원클릭 배포 템플릿
- [ ] AWS Bedrock 백엔드 지원
- [ ] Google Cloud Vertex AI 지원
- [ ] Azure OpenAI Service 지원
- [ ] 웹 관리 패널 강화 (사용량 통계, 모델 전환)
- [ ] 다중 사용자 API 키 관리
- [ ] Docker Compose 원클릭 로컬 배포

## 라이선스

MIT
