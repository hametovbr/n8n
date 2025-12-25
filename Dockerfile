# Stage 1: Build stage to install Python packages
FROM alpine:3.23 AS builder

# Install Python and pip
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip

# Install yt-dlp and gallery-dl via pip
RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    gallery-dl

# Stage 2: Final image based on n8n
FROM docker.n8n.io/n8nio/n8n:latest

# Switch to root to install packages
USER root

# Install ffmpeg and other dependencies using the n8n base package manager
# Check if apk exists, if not try apt-get
RUN if command -v apk >/dev/null 2>&1; then \
        apk update && apk add --no-cache ffmpeg curl wget; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && apt-get install -y --no-install-recommends ffmpeg curl wget && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "No package manager found" && exit 1; \
    fi

# Install Python pip if not present
RUN if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then \
        if command -v apk >/dev/null 2>&1; then \
            apk add --no-cache py3-pip; \
        elif command -v apt-get >/dev/null 2>&1; then \
            apt-get update && apt-get install -y python3-pip && rm -rf /var/lib/apt/lists/*; \
        fi \
    fi

# Install yt-dlp and gallery-dl directly in the n8n image
RUN pip3 install --break-system-packages yt-dlp gallery-dl 2>/dev/null || \
    pip3 install yt-dlp gallery-dl

# Create wrapper scripts in /usr/local/bin
RUN echo '#!/bin/sh' > /usr/local/bin/yt-dlp && \
    echo 'exec python3 -m yt_dlp "$@"' >> /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/sh' > /usr/local/bin/gallery-dl && \
    echo 'exec python3 -m gallery_dl "$@"' >> /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/gallery-dl

# Verify installations
RUN python3 --version && \
    test -f /usr/bin/ffmpeg && \
    /usr/local/bin/yt-dlp --version && \
    /usr/local/bin/gallery-dl --version

# Switch back to node user for security
USER node

# Health check to ensure n8n is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1