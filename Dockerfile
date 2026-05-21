FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    HF_HOME=/app/models \
    HF_HUB_DISABLE_TELEMETRY=1 \
    PYTHONUNBUFFERED=1

# PyTorch CPU-only (~200MB vs ~3GB com CUDA, e este servidor não tem GPU)
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch torchaudio && \
    pip install --no-cache-dir whisperlivekit python-multipart

WORKDIR /app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -sf http://127.0.0.1:8000/ -o /dev/null || exit 1

CMD ["whisperlivekit-server", \
     "--model", "medium", \
     "--language", "pt", \
     "--host", "0.0.0.0", \
     "--port", "8000"]
