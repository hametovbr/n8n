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

# Copy Python from builder
COPY --from=builder /usr/bin/python3* /usr/bin/
COPY --from=builder /usr/lib/python3.12 /usr/lib/python3.12
COPY --from=builder /usr/lib/libpython3.12.so* /usr/lib/

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

# Copy essential system libraries for Python and ffmpeg
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder /usr/lib/libz.so* /usr/lib/
COPY --from=builder /usr/lib/libbz2.so* /usr/lib/
COPY --from=builder /usr/lib/libexpat.so* /usr/lib/
COPY --from=builder /usr/lib/libffi.so* /usr/lib/
COPY --from=builder /usr/lib/libssl.so* /usr/lib/
COPY --from=builder /usr/lib/libcrypto.so* /usr/lib/

# Python site-packages are already in /usr/lib/python3.12 copied above

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