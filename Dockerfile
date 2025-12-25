# Stage 1: Build stage with full Alpine to get all binaries
FROM alpine:3.23 AS builder

# Install all required packages
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip \
    ffmpeg \
    ffmpeg-libs

# Install yt-dlp and gallery-dl via pip
RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    gallery-dl

# Stage 2: Final image based on n8n
FROM docker.n8n.io/n8nio/n8n:latest

# Switch to root to copy files
USER root

# Copy Python from builder
COPY --from=builder /usr/bin/python3* /usr/bin/
COPY --from=builder /usr/lib/python3.12 /usr/lib/python3.12
COPY --from=builder /usr/lib/libpython3.12.so* /usr/lib/

# Copy ffmpeg binaries
COPY --from=builder /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=builder /usr/bin/ffprobe /usr/bin/ffprobe

# Copy ALL libraries from Alpine to avoid missing dependencies
# This is simpler than tracking individual libraries
COPY --from=builder /usr/lib/ /usr/lib/
COPY --from=builder /lib/ /lib/

# Create wrapper scripts
RUN echo '#!/bin/sh' > /usr/local/bin/yt-dlp && \
    echo 'exec python3 -m yt_dlp "$@"' >> /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/sh' > /usr/local/bin/gallery-dl && \
    echo 'exec python3 -m gallery_dl "$@"' >> /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/gallery-dl

# Verify installations (basic check only)
RUN python3 --version && \
    ffmpeg -version && \
    ffprobe -version && \
    python3 -c "import yt_dlp; print('yt-dlp:', yt_dlp.version.__version__)" && \
    python3 -c "import gallery_dl; print('gallery-dl:', gallery_dl.version.__version__)"

# Switch back to node user for security
USER node

# Health check to ensure n8n is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1