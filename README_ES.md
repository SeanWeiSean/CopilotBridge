# CopilotBridge

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

Un proxy compartido de LiteLLM que permite a tu equipo usar modelos de GitHub Copilot (Claude, GPT, Gemini) a través de un único endpoint API compatible con OpenAI — sin necesidad de Docker ni autenticación por navegador en cada máquina.

> **Opciones de despliegue:**
> - **Railway (Inicio rápido)**: Crédito de prueba gratuito ($5), ideal para uso personal y pruebas. Aproximadamente 1 mes de uso gratuito. Sigue la guía a continuación.
> - **Azure Container Apps (Recomendado para producción)**: Ideal para equipos y uso a largo plazo. Consulta [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) — puedes completar el despliegue con herramientas de IA como Claude Code.

## Despliegue rápido en Railway

### 1. Fork y despliegue

1. Haz **Fork** de este repositorio en tu cuenta de GitHub
2. Ve a [railway.com](https://railway.com/) e inicia sesión con tu cuenta de GitHub
3. Si se solicita, **instala la Railway GitHub App** para otorgar acceso a tus repositorios
4. **New Project** → **Deploy from GitHub Repo** → selecciona tu fork de `CopilotBridge`
5. Railway comenzará a construir automáticamente

### 2. Configuración

Después del primer despliegue (se mostrará el asistente de autenticación), configura lo siguiente en Railway:

**Variables de entorno** (servicio → pestaña Variables → New Variable):

| Variable | Valor |
|---|---|
| `LITELLM_MASTER_KEY` | Una clave secreta fuerte (al menos 32 caracteres aleatorios). Usa un generador de contraseñas. Ejemplo: `sk-` + 32 caracteres hexadecimales aleatorios |
| `RAILWAY_RUN_UID` | `0` |

> **🚨 ¡DEBES configurar `LITELLM_MASTER_KEY`!** Sin ella, el proxy queda completamente abierto — cualquier persona en Internet puede llamar a modelos de IA a través de tu proxy, lo que puede causar **pérdidas financieras graves y riesgo para tu cuenta**.

**Red** (servicio → pestaña Settings → Networking):

- En **Public Networking**, haz clic en **Generate Domain**

**Ruta del Dockerfile** (servicio → pestaña Settings → Build):

- Establece **Custom Dockerfile Path** como `railway/Dockerfile`

**Desactivar auto-despliegue** (servicio → pestaña Settings → Source):

- Encuentra **Branch connected to production** y haz clic en **Disconnect**
- Esto evita que los push de código activen redespliegues automáticos (los redespliegues borran las credenciales OAuth)

### 3. Autenticación con GitHub Copilot

1. Abre la URL de tu dominio Railway en un navegador
2. Verás el **asistente de autenticación CopilotBridge**
3. Haz clic en **Begin Authentication**
4. Aparecerá un código de dispositivo — haz clic en **Open GitHub** e ingresa el código
5. Autoriza en GitHub (~10 segundos)
6. El proxy se reinicia automáticamente en modo API

### 4. Usa el proxy

```bash
curl https://your-app.up.railway.app/v1/chat/completions \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "¡Hola!"}]}'
```

### Modelos disponibles

| Proveedor | Modelos |
|-----------|---------|
| **Anthropic** | claude-sonnet-4, claude-sonnet-4.5, claude-sonnet-4.6, claude-opus-4.5, claude-opus-4.6, claude-opus-4.6-1m, claude-haiku-4.5 |
| **OpenAI** | gpt-4o, gpt-4.1, gpt-5-mini, gpt-5.1, gpt-5.2, gpt-5.4 |
| **Google** | gemini-2.5-pro, gemini-3-flash-preview, gemini-3.1-pro-preview |
| **Otros** | minimax-m2.5 |

---

## Despliegue en Azure

Para el despliegue en Azure Container Apps, consulta [copilot-litellm-azure-deployment.md](copilot-litellm-azure-deployment.md) y el directorio `scripts/`.

## Licencia

MIT
