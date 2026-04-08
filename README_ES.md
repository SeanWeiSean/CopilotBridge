# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

Un proxy inverso de la API de GitHub Copilot, exponiéndola como un servicio compatible con OpenAI y Anthropic. Usa modelos de Copilot (Claude, GPT, Gemini) en Claude Code, Cursor, scripts, CI/CD y cualquier lugar que soporte la API de OpenAI.

> [!WARNING]
> Este es un proxy de ingeniería inversa de la API de GitHub Copilot. **No está soportado por GitHub** y puede dejar de funcionar inesperadamente. Úselo bajo su propio riesgo.

> [!WARNING]
> **Aviso de seguridad de GitHub:**
> El uso excesivo automatizado de Copilot puede activar los [sistemas de detección de abuso](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) de GitHub.
> Políticas: [Políticas de uso aceptable](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies) · [Términos de GitHub Copilot](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#github-copilot)
>
> **Use este proxy de manera responsable para evitar restricciones de cuenta.**

## ¿Por qué CopilotBridge?

Ya tienes una suscripción a GitHub Copilot, pero sus capacidades están encerradas en VS Code y la UI de GitHub. CopilotBridge te permite:

- Usar los modelos Claude/GPT de Copilot en **Claude Code**
- Llamar a modelos Copilot desde **Cursor**, **Continue** y otros plugins de IDE
- Integrar IA en **scripts de automatización y CI/CD**
- Acceder a los modelos vía API desde **cualquier dispositivo** — sin login por navegador
- Autenticarte una vez, **usar en todas partes**

## Opciones de Despliegue

| Método | Ideal para | Costo |
|--------|-----------|-------|
| **🖥️ Local** | Uso personal, inicio más rápido | Gratis |
| **🚂 Railway** | Sin Docker local, acceso desde cualquier lugar | Prueba gratis ($5 de crédito, ~1 mes) |
| **☁️ Azure** | Estabilidad a largo plazo, funciones empresariales | Precios de Azure |

---

## 🖥️ Ejecución Local (Inicio Más Rápido)

Solo Docker, 3 pasos:

### 1. Iniciar el Proxy

```bash
docker run -it --rm \
    -p 4000:4000 \
    -v litellm_config:/root/.config \
    -v $(pwd)/litellm_config.yaml:/app/config.yaml:ro \
    -e LITELLM_MASTER_KEY=sk-your-secret-key \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml --host 0.0.0.0 --port 4000
```

### 2. Autenticar con GitHub

Ingresa el código de dispositivo mostrado en la terminal en tu navegador.

### 3. Usar

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "¡Hola!"}]}'
```

---

## 🚂 Despliegue en Railway (Sin Docker Local)

Railway ofrece **$5 de crédito gratis** (~1 mes).

1. Haz **Fork** de este repo → inicia sesión en [railway.com](https://railway.com/) con GitHub → **Deploy from GitHub Repo**
2. Configura variables: `LITELLM_MASTER_KEY` (clave secreta fuerte), `RAILWAY_RUN_UID=0`
3. Settings → Networking → **Generate Domain**
4. Settings → Build → Custom Dockerfile Path → `railway/Dockerfile`
5. Settings → Source → **Disconnect** (desactivar auto-despliegue)
6. Abre la URL del dominio y completa el asistente de autenticación

> **🚨 ¡DEBES configurar `LITELLM_MASTER_KEY`!** Sin ella, puede causar **pérdidas financieras graves y riesgo para tu cuenta**.

---

## ☁️ Despliegue en Azure (Recomendado para Uso a Largo Plazo)

Consulta [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md). Puedes completar el despliegue con herramientas de IA como Claude Code.

## Modelos Disponibles

| Proveedor | Modelos |
|-----------|---------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **Otros** | minimax-m2.5 |

## Roadmap

- [ ] Persistencia de credenciales OAuth en Railway (configuración automática de Volume)
- [ ] Plantilla de despliegue con un clic para Railway
- [ ] Soporte para AWS Bedrock como backend de modelos adicional
- [ ] Soporte para Google Cloud Vertex AI
- [ ] Soporte para Azure OpenAI Service
- [ ] Panel de administración web mejorado (estadísticas de uso, cambio de modelos)
- [ ] Gestión de claves API multi-usuario
- [ ] Despliegue local con Docker Compose en un clic

## Licencia

MIT
