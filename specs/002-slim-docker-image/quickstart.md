# Quickstart: Slim Docker Image

**Feature**: 002-slim-docker-image
**Date**: 2026-03-25

## What This Feature Does

Updates the mowmo Dockerfile to remove packages made obsolete by the Electron + cage architecture pivot, add the cage compositor, and switch to pre-compiled binary packages (paru-bin, llama.cpp-bin) to eliminate build toolchain dependencies.

## Key Files

| File | Change |
|------|--------|
| `Dockerfile` | Rewrite package lists, switch AUR build strategy |

## Build & Verify

```bash
# Build the image
docker build -t mowmo:latest .

# Verify removed packages are gone
docker run mowmo:latest pacman -Q hyprland 2>&1        # should say "not found"
docker run mowmo:latest pacman -Q webkit2gtk-4.1 2>&1  # should say "not found"
docker run mowmo:latest pacman -Q rustup 2>&1           # should say "not found"

# Verify added/kept packages are present
docker run mowmo:latest which cage                      # should return /usr/bin/cage
docker run mowmo:latest which llama-server              # should return valid path
docker run mowmo:latest which paru                      # should return valid path

# Check image size (should be under 1.5GB excluding model)
docker images mowmo:latest --format '{{.Size}}'
```

## Run Tests

```bash
make test
```

## Key Decisions

1. **cage** installed from official `extra` repo (not AUR)
2. **paru** built from source — paru-bin rejected due to libalpm.so version mismatch on Arch's rolling release. Build tools (rustup, base-devel) installed and removed in the same Docker layer.
3. **llama.cpp-bin** replaces llama.cpp source build (pre-compiled binary, no cmake/gcc needed)
4. **Same-layer cleanup** — base-devel and rustup are temporarily installed for paru compilation, then removed with `pacman -Rns` in the same RUN command so they don't persist in the final image
5. **Electron** is NOT in this Dockerfile — bundled with desktop app during ISO build
6. **xdg-utils** remains as a transitive dependency of sddm→qt6-base (cannot be removed without removing sddm)
