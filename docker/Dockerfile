## Base builder
#

FROM node:20 AS builder

ARG JELLYFIN_TAG=v10.11.5
RUN test -n "${JELLYFIN_TAG}" || (echo "JELLYFIN_TAG required" && exit 1)

# Create non-root user
RUN useradd --home-dir /build --create-home --shell /bin/bash builder
USER builder

#
# Checkout jellyfin-web and jellyfin-tizen repositories

RUN \
    git clone \
    --depth 1 \
    --branch "${JELLYFIN_TAG}" \
    https://github.com/jellyfin/jellyfin-web.git \
    /build/jellyfin-web

RUN \
    git clone \
    --depth 1 \
    https://github.com/jellyfin/jellyfin-tizen.git \
    /build/jellyfin-tizen

#
# Build jellyfin-web
WORKDIR /build/jellyfin-web
RUN \
    SKIP_PREPARE=1 \
    npm \
    clean-install \
    --no-audit
# RUN npx update-browserslist-db@latest
RUN \
    USE_SYSTEM_FONTS=1 \
    npm \
    run build:production

#
# Build jellyfin-tizen using /build/jellyfin-web outout
WORKDIR /build/jellyfin-tizen
RUN \
    JELLYFIN_WEB_DIR=/build/jellyfin-web/dist/ \
    npm \
    clean-install --no-audit

##
# Build image prepared for run tizen-studio

FROM debian:13-slim AS runtime

LABEL org.opencontainers.image.source=https://github.com/ldotlopez/jellyfin-tizen-installer

# Install packages that will be needed by tizen-studio inside the container
ENV DEBIAN_FRONTEND=noninteractive
RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        curl \
        default-jre \
        expect \
        sudo \
        tini && \
    rm -rf \
        /var/cache/apt/*.bin \
        /var/cache/apt/archives/*.deb \
        /var/cache/apt/archives/partial/* \
        /var/lib/apt/lists/*

# Copy processed source in /src
#
WORKDIR /src
COPY --from=builder /build/jellyfin-tizen/config.xml ./
COPY --from=builder /build/jellyfin-tizen/icon.png ./
COPY --from=builder /build/jellyfin-tizen/index.html ./
COPY --from=builder /build/jellyfin-tizen/tizen.js ./
COPY --from=builder /build/jellyfin-tizen/www/ ./www/

WORKDIR /
COPY --chmod=0755 entrypoint.sh run.sh ./

CMD ["/entrypoint.sh"]
