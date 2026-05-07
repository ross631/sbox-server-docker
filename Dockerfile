# syntax=docker/dockerfile:1.7

# ─────────────────────────────────────────────────────────────────────
# sbox-server Docker image
#
# Runs the s&box dedicated server (Steam app 1892930) under Wine on
# Alpine, with the Microsoft .NET 10 runtime dropped into the Wine
# prefix. Same shape as gio3k/sbox-server-wine-docker, kept current
# with Facepunch's release cycle and our LAN's needs.
#
# Build: ~30 min, ~15 GB free disk required during build.
# Final image: ~2.7 GB.
# ─────────────────────────────────────────────────────────────────────

ARG SBOX_BETA=public

# ─── Builder ─────────────────────────────────────────────────────────
# Pulls Wine prerequisites, the s&box dedicated server (via SteamCMD),
# and Microsoft's portable .NET 10 runtime. Assembles a wine prefix +
# server install that the runtime stage copies in wholesale.

FROM debian:trixie-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG SBOX_BETA

RUN apt-get update && \
    dpkg --add-architecture i386 && \
    sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' \
        /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget unzip cabextract \
        wine wine32 wine64 libwine libwine:i386 fonts-wine winbind \
        xserver-xorg-core xvfb xauth psmisc && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get install -y steamcmd && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# winetricks isn't always packaged; pull script directly from upstream
RUN wget -qO /usr/local/bin/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Bootstrap Wine prefix with the Visual C++ 2022 runtime that s&box
# binaries link against. Note we do NOT install dotnet via winetricks —
# the dotnet10 verb defaults to the x86 installer which fails under
# xvfb-run; we drop the portable .NET 10 zip in below instead.
RUN mkdir -p /work && cd /work && \
    WINEPREFIX=/work/wineprefix xvfb-run -a winetricks -q --force win10 vcrun2022

# s&box dedicated server (Windows platform pull via SteamCMD)
RUN mkdir -p /work/server && \
    /usr/games/steamcmd \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir /work/server \
        +login anonymous \
        +app_update 1892930 validate \
        -beta "$SBOX_BETA" \
        +quit

# Microsoft .NET 10 runtime — portable zip dropped at the standard
# C:\Program Files\dotnet path inside the wine prefix. aka.ms shortlink
# resolves to the latest 10.0.x x64 build automatically.
RUN mkdir -p '/work/wineprefix/drive_c/Program Files/dotnet' && \
    cd /tmp && \
    wget -qO dotnet.zip https://aka.ms/dotnet/10.0/dotnet-runtime-win-x64.zip && \
    unzip -qo dotnet.zip -d '/work/wineprefix/drive_c/Program Files/dotnet' && \
    rm dotnet.zip

# Slim the Wine package cache (only used during vcrun install)
RUN rm -rf "/work/wineprefix/drive_c/ProgramData/Package Cache"

# ─── Runtime ─────────────────────────────────────────────────────────
# Minimal Alpine + Wine. Wine prefix and server install are copied in
# from the builder stage.

FROM alpine:edge

RUN adduser -D -g "steam" steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    apk add --no-cache wine gnutls && \
    rm -rf /usr/lib/libLLVM* /usr/lib/libgallium* /usr/lib/gallium-pipe

COPY --from=builder --chown=steam:steam /work/wineprefix /home/steam/.wine
COPY --from=builder --chown=steam:steam /work/server /home/steam/server

USER steam
ENV WINEDEBUG=-all
ENV XDG_RUNTIME_DIR=/tmp

# Force-register the wine prefix once so first start is faster
RUN wine "" || true

# Pass-through entrypoint: container args become +flags for sbox-server.exe
RUN printf '%s\n' '#!/bin/ash' \
                  'exec wine ~/server/sbox-server.exe "$@"' \
                  > /home/steam/start-server.sh && \
    chmod +x /home/steam/start-server.sh

ENTRYPOINT ["/home/steam/start-server.sh"]
