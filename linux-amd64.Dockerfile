ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_AMD64

# --- rtorrent builder, unchanged ------------------------------------
FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_AMD64} AS builder
RUN apk add --no-cache build-base linux-headers curl-dev ncurses-dev tinyxml2-dev
ARG RTORRENT_VERSION
RUN mkdir "/tmp/libtorrent" && \
    curl -fsSL "https://github.com/rakshasa/rtorrent/releases/download/v${RTORRENT_VERSION}/libtorrent-${RTORRENT_VERSION}.tar.gz" | tar xzf - -C "/tmp/libtorrent" --strip-components=1 && \
    cd "/tmp/libtorrent" && \
    ./configure --disable-debug --disable-shared --enable-static --enable-aligned && \
    make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" && \
    make install
RUN mkdir "/tmp/rtorrent" && \
    curl -fsSL "https://github.com/rakshasa/rtorrent/releases/download/v${RTORRENT_VERSION}/rtorrent-${RTORRENT_VERSION}.tar.gz" | tar xzf - -C "/tmp/rtorrent" --strip-components=1 && \
    cd "/tmp/rtorrent" && \
    ./configure --disable-debug --disable-shared --enable-static --enable-aligned --with-xmlrpc-tinyxml2 && \
    make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing" && \
    make install

# --- final image ----------------------------------------------------
FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_AMD64}
EXPOSE 3000 5000
ARG IMAGE_STATS
ENV IMAGE_STATS=${IMAGE_STATS} \
    FLOOD_AUTH="false" \
    WEBUI_PORTS="3000/tcp,3000/udp,5000/tcp,5000/udp"

# add rsync + ssh client here
RUN apk add --no-cache \
      xmlrpc-c-tools \
      nginx \
      openssl \
      mediainfo \
      rsync \
      openssh-client \
    && ln -s "${CONFIG_DIR}/rpc2/basic_auth_credentials" "${APP_DIR}/basic_auth_credentials"

COPY --from=builder /usr/local/bin/rtorrent "${APP_DIR}/rtorrent"

# Use YOUR flood fork instead of upstream
ARG FLOOD_VERSION
ARG FLOOD_REPO_OWNER="your-github-user-or-org"   # <--- set this in your build args or hardcode

RUN curl -fsSL "https://github.com/upsite4k/flood/releases/download/v${FLOOD_VERSION}/flood-linux-x64" > "${APP_DIR}/flood" && \
    chmod 755 "${APP_DIR}/flood"

# rootfs overlay (we’ll put transfer script here)
COPY root/ /

# make sure script is executable (path matches what we’ll use from Flood)
RUN chmod +x /app/transfer-torrent.sh
RUN chmod +x /app/update-kodi.sh
