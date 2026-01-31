FROM docker.n8n.io/n8nio/n8n:latest

USER root

RUN apt update && apt install -y --no-install-recommends \
    python3 \
    python3-pip \
    ffmpeg \
    imagemagick \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp and gallery-dl via pip
RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    gallery-dl

# В Debian/Ubuntu ImageMagick часто блокирует операции из-за политики безопасности.
# Эта команда разрешает чтение/запись для большинства операций.
RUN sed -i 's/domain="coder" rights="none" pattern="PDF"/domain="coder" rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true

# Создаем воркеры
RUN echo '#!/bin/sh' > /usr/local/bin/yt-dlp && \
    echo 'exec python3 -m yt_dlp "$@"' >> /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/sh' > /usr/local/bin/gallery-dl && \
    echo 'exec python3 -m gallery_dl "$@"' >> /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/gallery-dl

USER node

# Health check to ensure n8n is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1
