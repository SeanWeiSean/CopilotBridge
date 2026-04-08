FROM ghcr.io/berriai/litellm:main-latest

# Copy LiteLLM model config
COPY litellm_config.yaml /app/config.yaml

# Copy auth wizard
COPY railway/ /app/railway/

# Make entrypoint executable
RUN chmod +x /app/railway/entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["sh", "/app/railway/entrypoint.sh"]
