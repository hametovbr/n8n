# Stage 1: Build stage with full Alpine to install packages
FROM alpine:3.23 AS builder

# Install all required packages
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip \
    ffmpeg \
    curl \
    wget \
    bash

# Install yt-dlp and gallery-dl via pip
RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    gallery-dl

# Create wrapper scripts
RUN echo '#!/bin/bash\npython3 -m yt_dlp "$@"' > /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/bash\npython3 -m gallery_dl "$@"' > /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/gallery-dl

# Stage 2: Final image based on n8n
FROM docker.n8n.io/n8nio/n8n:latest

# Switch to root to copy files
USER root

# Copy installed packages and binaries from builder stage
COPY --from=builder /usr/bin/python3* /usr/bin/
COPY --from=builder /usr/bin/ffmpeg /usr/bin/
COPY --from=builder /usr/bin/ffprobe /usr/bin/
COPY --from=builder /usr/bin/curl /usr/bin/
COPY --from=builder /usr/bin/wget /usr/bin/
COPY --from=builder /bin/bash /bin/
COPY --from=builder /usr/lib/python3* /usr/lib/
COPY --from=builder /usr/lib/libpython* /usr/lib/
COPY --from=builder /usr/lib/libav* /usr/lib/
COPY --from=builder /usr/lib/libsw* /usr/lib/
COPY --from=builder /usr/lib/libpost* /usr/lib/
COPY --from=builder /usr/lib/libx264* /usr/lib/
COPY --from=builder /usr/lib/libx265* /usr/lib/
COPY --from=builder /usr/lib/libvpx* /usr/lib/
COPY --from=builder /usr/lib/libopus* /usr/lib/
COPY --from=builder /usr/lib/libvorbis* /usr/lib/
COPY --from=builder /usr/lib/libogg* /usr/lib/
COPY --from=builder /usr/lib/libtheo* /usr/lib/
COPY --from=builder /usr/lib/libcurl* /usr/lib/
COPY --from=builder /usr/local/bin/yt-dlp /usr/local/bin/
COPY --from=builder /usr/local/bin/gallery-dl /usr/local/bin/

# Verify installations
RUN python3 --version && \
    ffmpeg -version && \
    yt-dlp --version && \
    gallery-dl --version

# Switch back to node user for security
USER node

# Health check to ensure n8n is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1