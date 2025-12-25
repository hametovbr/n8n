# Stage 1: Build stage with full Alpine to get all binaries
FROM alpine:3.23 AS builder

# Install all required packages
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip \
    ffmpeg \
    ffmpeg-libs \
    curl \
    wget

# Install yt-dlp and gallery-dl via pip
RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    gallery-dl

# Stage 2: Final image based on n8n
FROM docker.n8n.io/n8nio/n8n:latest

# Switch to root to copy files
USER root

# Copy ffmpeg and related binaries
COPY --from=builder /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=builder /usr/bin/ffprobe /usr/bin/ffprobe

# Copy all ffmpeg libraries
COPY --from=builder /usr/lib/libavcodec.so* /usr/lib/
COPY --from=builder /usr/lib/libavdevice.so* /usr/lib/
COPY --from=builder /usr/lib/libavfilter.so* /usr/lib/
COPY --from=builder /usr/lib/libavformat.so* /usr/lib/
COPY --from=builder /usr/lib/libavutil.so* /usr/lib/
COPY --from=builder /usr/lib/libswresample.so* /usr/lib/
COPY --from=builder /usr/lib/libswscale.so* /usr/lib/
COPY --from=builder /usr/lib/libpostproc.so* /usr/lib/

# Copy codec libraries
COPY --from=builder /usr/lib/libx264.so* /usr/lib/
COPY --from=builder /usr/lib/libx265.so* /usr/lib/
COPY --from=builder /usr/lib/libvpx.so* /usr/lib/
COPY --from=builder /usr/lib/libaom.so* /usr/lib/
COPY --from=builder /usr/lib/libdav1d.so* /usr/lib/
COPY --from=builder /usr/lib/libopus.so* /usr/lib/
COPY --from=builder /usr/lib/libvorbis.so* /usr/lib/
COPY --from=builder /usr/lib/libvorbisenc.so* /usr/lib/
COPY --from=builder /usr/lib/libogg.so* /usr/lib/
COPY --from=builder /usr/lib/libtheoraenc.so* /usr/lib/
COPY --from=builder /usr/lib/libtheoradec.so* /usr/lib/
COPY --from=builder /usr/lib/libtheora.so* /usr/lib/
COPY --from=builder /usr/lib/libmp3lame.so* /usr/lib/
COPY --from=builder /usr/lib/libwebp.so* /usr/lib/
COPY --from=builder /usr/lib/libwebpmux.so* /usr/lib/

# Copy Python site-packages with yt-dlp and gallery-dl
COPY --from=builder /usr/lib/python3.12/site-packages/yt_dlp /usr/local/lib/python3.12/site-packages/yt_dlp
COPY --from=builder /usr/lib/python3.12/site-packages/yt_dlp-*.dist-info /usr/local/lib/python3.12/site-packages/
COPY --from=builder /usr/lib/python3.12/site-packages/gallery_dl /usr/local/lib/python3.12/site-packages/gallery_dl
COPY --from=builder /usr/lib/python3.12/site-packages/gallery_dl-*.dist-info /usr/local/lib/python3.12/site-packages/

# Create wrapper scripts
RUN echo '#!/bin/sh' > /usr/local/bin/yt-dlp && \
    echo 'exec python3 -m yt_dlp "$@"' >> /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/sh' > /usr/local/bin/gallery-dl && \
    echo 'exec python3 -m gallery_dl "$@"' >> /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/gallery-dl

# Verify installations (basic check only)
RUN python3 --version && \
    which ffmpeg && \
    python3 -c "import yt_dlp; print('yt-dlp:', yt_dlp.version.__version__)" && \
    python3 -c "import gallery_dl; print('gallery-dl:', gallery_dl.version.__version__)"

# Switch back to node user for security
USER node

# Health check to ensure n8n is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1