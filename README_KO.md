# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

GitHub Copilot 모델(Claude, GPT, Gemini)을 단일 OpenAI 호환 API 엔드포인트로 팀과 공유할 수 있는 LiteLLM 프록시입니다. 각 머신에서 Docker 설정이나 브라우저 인증이 필요 없습니다.

> **배포 방식 선택:**
> - **Railway (빠른 체험)**: 무료 체험 크레딧($5)이 있어 개인 사용 및 테스트에 적합합니다. 약 1개월 무료 사용 가능. 아래 가이드를 따르세요.
> - **Azure Container Apps (프로덕션 권장)**: 팀 장기 사용에 최적. [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md)를 참조하세요. Claude Code 같은 AI 도구로 배포를 완료할 수 있습니다.

## Railway 빠른 배포

### 1. Fork & 배포

1. 이 저장소를 GitHub 계정으로 **Fork**
2. [railway.com](https://railway.com/)에서 GitHub 계정으로 로그인
3. 프롬프트가 표시되면 **Railway GitHub App 설치**로 저장소 접근 권한 부여
4. **New Project** → **Deploy from GitHub Repo** → Fork한 `CopilotBridge` 선택
5. Railway가 자동으로 빌드 시작

### 2. 설정

첫 번째 배포 후(인증 마법사가 표시됨), Railway에서 다음을 설정:

**환경 변수** (서비스 → Variables 탭 → New Variable):

| 변수 | 값 |
|---|---|
| `LITELLM_MASTER_KEY` | 강력한 비밀 키 (32자 이상 랜덤 문자). 비밀번호 생성기를 사용하세요. 예: `sk-` + 랜덤 32자리 16진수 |
| `RAILWAY_RUN_UID` | `0` |

> **🚨 `LITELLM_MASTER_KEY`를 반드시 설정하세요!** 설정하지 않으면 프록시가 완전히 개방되어 인터넷의 누구나 AI 모델을 호출할 수 있으며, **심각한 금전적 손실과 계정 위험**이 발생할 수 있습니다.

**네트워크** (서비스 → Settings 탭 → Networking):

- **Public Networking**에서 **Generate Domain** 클릭

**Dockerfile 경로** (서비스 → Settings 탭 → Build):

- **Custom Dockerfile Path**를 `railway/Dockerfile`로 설정

**자동 배포 비활성화** (서비스 → Settings 탭 → Source):

- **Branch connected to production**을 찾아 **Disconnect** 클릭
- 코드 push로 인한 자동 재배포를 방지합니다 (재배포 시 OAuth 자격 증명이 손실됨)

### 3. GitHub Copilot 인증

1. 브라우저에서 Railway 도메인 URL 열기
2. **CopilotBridge 인증 마법사**가 표시됨
3. **Begin Authentication** 클릭
4. 디바이스 코드가 표시됨 → **Open GitHub** 클릭하여 코드 입력
5. GitHub에서 인증 (약 10초)
6. 프록시가 자동으로 재시작하여 API 모드로 전환

### 4. 프록시 사용

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "안녕하세요!"}]}'
```

### 사용 가능한 모델

| 제공업체 | 모델 |
|----------|------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **기타** | minimax-m2.5 |

---

## Azure 배포

Azure Container Apps 배포는 [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md)와 `scripts/` 디렉토리를 참조하세요.

## 라이선스

MIT
