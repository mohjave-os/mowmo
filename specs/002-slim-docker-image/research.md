# Research: Slim Docker Image

**Date**: 2026-03-25
**Feature**: 002-slim-docker-image

## Decision 1: cage Package Source

**Decision**: Install cage via `pacman -S cage` (official `extra` repo)

**Rationale**: cage is available in Arch Linux's official `extra` repository as package `cage` (v0.2.1). No AUR build needed. This simplifies the Dockerfile — cage goes in the same `pacman -S` block as all other official packages.

**Alternatives considered**:
- AUR build: Unnecessary — package is in official repos
- Building from source: Over-engineering for a packaged compositor

## Decision 2: paru Build Strategy

**Decision**: Build paru from source in a single Docker RUN layer, then remove build tools (rustup, base-devel) in the same layer

**Rationale**: `paru-bin` (pre-compiled binary) fails at runtime due to `libalpm.so` version mismatch — Arch Linux is a rolling release and pre-compiled AUR binaries go stale quickly. Building paru from source and removing build tools in the same RUN layer ensures: (a) paru links against the current libalpm, and (b) rustup/base-devel don't persist in the final image. The build layer adds ~135MB to the image.

**Alternatives considered**:
- paru-bin: Failed — linked against libalpm.so.15 but current Arch ships a newer version
- Keep paru + build tools permanently: Wastes ~700MB for tools never used at runtime
- yay-bin: Another AUR helper, but paru is the project standard (Decision 1, MOH-367)

## Decision 3: base-devel Removal Strategy

**Decision**: Install base-devel temporarily in the same RUN layer as the paru source build, then remove it after compilation.

**Rationale**: Building paru from source requires the full base-devel group (gcc, make, etc.) and rustup. The fakeroot-only approach failed because paru-bin has libalpm version mismatches. Instead, we install base-devel + rustup, build paru, install llama.cpp-bin via paru, then `pacman -Rns` both in the same RUN layer. Docker only stores the final filesystem state of each layer, so removed packages don't bloat the image.

**Alternatives considered**:
- fakeroot only (no base-devel): Failed — paru-bin's pre-compiled binary has libalpm version mismatch
- Multi-stage Docker build: Impractical for a full Arch Linux OS image
- Keep base-devel permanently: Wastes ~200MB for packages never used at runtime

## Decision 4: llama.cpp Binary Package

**Decision**: Switch from `llama.cpp` (source build) to `llama.cpp-bin` (pre-compiled binary from AUR)

**Rationale**: `llama.cpp` (source) requires cmake + gcc for full C++ compilation. `llama.cpp-bin` downloads precompiled x86_64 binaries from official GitHub releases, provides the same `llama-server` binary, and has zero makedepends. Runtime depends are only `curl` and `gcc-libs`. The `llama.cpp-bin` package `provides=('llama.cpp')` so it satisfies the same dependency.

**Alternatives considered**:
- Source build with base-devel cleanup: Works but adds minutes of compile time and requires build tools
- llama.cpp-cuda or llama.cpp-vulkan variants: Only needed for GPU acceleration; base CPU build sufficient for initial image

## Decision 5: Electron Installation

**Decision**: Electron is NOT installed in the Dockerfile. It is bundled with the mohjave-desktop Electron app and added during ISO build.

**Rationale**: Per MOH-392, Electron is bundled with the desktop app (built separately, copied into the ISO at `/usr/share/mohjave/desktop/`). Using the Arch `electron` system package could conflict with the app-bundled version. This is not a mowmo Dockerfile concern.

**Alternatives considered**:
- Install `electron` via pacman: Could conflict with app-bundled version, adds complexity
