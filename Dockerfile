# Stage 1: Собираем всё в Alpine
FROM alpine:3.21 AS builder

RUN apk add --no-cache \
    python3 \
    py3-pip \
    ffmpeg \
    imagemagick \
    imagemagick-jpeg \
    imagemagick-webp \
    potrace 

RUN pip3 install --no-cache-dir --break-system-packages yt-dlp gallery-dl

# Stage 2: Финальный образ n8n
FROM docker.n8n.io/n8nio/n8n:latest

USER root

# 1. Копируем исполняемые файлы (бинарники)
COPY --from=builder /usr/bin/magick /usr/bin/magick
COPY --from=builder /usr/bin/convert /usr/bin/convert
COPY --from=builder /usr/bin/identify /usr/bin/identify
COPY --from=builder /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=builder /usr/bin/python3* /usr/bin/
COPY --from=builder /usr/bin/potrace /usr/bin/potrace

# 2. Копируем библиотеки
COPY --from=builder /usr/lib/ /usr/lib/
COPY --from=builder /lib/ /lib/

# 3. Копируем конфигурацию ImageMagick (важно для кодеков)
COPY --from=builder /etc/ImageMagick-7/ /etc/ImageMagick-7/

# 4. Пробрасываем Python пакеты
COPY --from=builder /usr/lib/python3.12/site-packages /usr/lib/python3.12/site-packages

# Врапперы для yt-dlp и gallery-dl
RUN echo '#!/bin/sh\nexec python3 -m yt_dlp "$@"' > /usr/local/bin/yt-dlp && \
    echo '#!/bin/sh\nexec python3 -m gallery_dl "$@"' > /usr/local/bin/gallery-dl && \
    chmod +x /usr/local/bin/yt-dlp /usr/local/bin/gallery-dl

USER node
