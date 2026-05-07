# sbox-server

Maintained Docker image for the [s&box](https://sbox.game) dedicated server.

s&box is open source ([Facepunch/sbox-public](https://github.com/Facepunch/sbox-public)),
but the dedicated server itself is shipped as a Windows binary on Steam
(app `1892930`). This image runs that binary under [Wine](https://www.winehq.org/)
on Alpine, with the Microsoft .NET 10 runtime dropped into the Wine prefix.

Same shape as [gio3k/sbox-server-wine-docker](https://github.com/gio3k/sbox-server-wine-docker),
kept current with Facepunch's release cycle (nightly automated builds).

## Quick start

```bash
docker run -d \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v sbox-data:/home/steam/server/addons/custom \
  ghcr.io/ross631/sbox-server:latest \
  +game /home/steam/server/addons/custom/mygame.sbproj \
  +sv_password mypassword \
  +rcon_password myrconpassword
```

Container args are passed through to `sbox-server.exe` as Wine startup
flags. Mount your gamemode (`addons/custom`) and point `+game` at the
sbproj file.

## Tags

| Tag | Meaning |
|---|---|
| `:latest` | Most recent successful build of `main` |
| `:YYYY-MM-DD` | Daily snapshot, immutable |
| `:sha-<short>` | Per-commit, immutable |

## What's inside

- `debian:trixie-slim` builder stage: Wine + i386 multilib + SteamCMD,
  installs the s&box dedicated server (Windows binaries) and bootstraps
  a Wine prefix with `vcrun2022`.
- `alpine:edge` runtime stage: Wine + the prefix and server install
  copied from the builder. Runs as the unprivileged `steam` user.
- Microsoft .NET 10 runtime (portable zip) extracted to the standard
  `C:\Program Files\dotnet` path inside the Wine prefix.

The Wine prefix is **64-bit** and pre-warmed; first container start is
fast (no winetricks/install steps at runtime).

## Building locally

```bash
git clone https://github.com/ross631/sbox-server-docker.git
cd sbox-server-docker
docker build -t sbox-server .
```

Build takes ~30 minutes on a typical wired connection. Needs ~15 GB
free disk during the build (most reclaimed afterward — final image is
~2.7 GB).

To pull a different s&box beta channel pass `--build-arg SBOX_BETA=staging`
(or whatever channel you have access to).

## Forking

Fork this repo on GitHub. Enable Actions on the fork (Settings → Actions
→ Allow). The workflow publishes to `ghcr.io/<your-handle>/sbox-server`
under your account on every push to `main`, on the daily schedule, and
on manual `workflow_dispatch`.

Common fork customizations:

- Change `vcrun2022` → another Visual C++ runtime version
- Bake additional addons into the image at build time
- Pin to a specific s&box build via `SBOX_BETA`
- Swap the .NET 10 zip URL for a different runtime version

## Why not gio3k/sbox-server-wine-docker?

That image is the prior art and works great when it's current. As of
2026-05, the published `:latest` tag is from Dec 2025 with .NET 9
hardcoded — Facepunch bumped s&box to .NET 10 and the image stopped
working. We needed a maintained alternative, so here we are.

## License

MIT — see [LICENSE](LICENSE).
