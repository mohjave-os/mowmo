# mowmo

Package manager CLI and Arch Linux base image for [Mohjave OS](https://mohjave.com).

## What is mowmo?

mowmo is the package management layer for Mohjave OS. It wraps `pacman` and `paru` (AUR) behind a unified CLI that outputs structured JSON by default, designed for consumption by the Mohjave kernel orchestrator.

The Docker image ships everything needed for the Mohjave runtime:
- **LLM inference** -- llama.cpp (`llama-server`), serving the mohwise-ankur-4b model (Qwen3.5-4B fine-tune)
- **TTS** -- Kokoro-82M via ONNX Runtime, with `espeak-ng` for phonemization
- **Voice input** -- whisper-rs, using PipeWire for audio capture
- **Compositor** -- cage (single-window Wayland kiosk)
- **Desktop** -- Electron (the sole GUI, launched inside cage)

## Quick Start

### Build the image

```bash
docker build -t mowmo:latest .
```

### Verify

```bash
docker run --rm mowmo:latest llama-server --version
docker run --rm mowmo:latest pacman -Q cage pipewire wireplumber espeak-ng
docker run --rm mowmo:latest paru --version
docker run --rm mowmo:latest mowmo list --human | head -20
```

### Use mowmo

```bash
docker run --rm -it mowmo:latest bash

# JSON output (default)
mowmo search editor
mowmo install firefox
mowmo info firefox
mowmo list
mowmo update
mowmo remove firefox

# Human-readable output
mowmo install firefox --human
```

### Run tests

```bash
make test
```

### Push to registry

```bash
make push
```

## Commands

| Command | Description |
|---------|-------------|
| `mowmo install <pkg>` | Install a package (pacman, falls back to AUR) |
| `mowmo remove <pkg>` | Remove an installed package |
| `mowmo search <query>` | Search package repositories |
| `mowmo update` | Full system update (pacman -Syu) |
| `mowmo list` | List all installed packages |
| `mowmo info <pkg>` | Show detailed package information |

### Global Flags

| Flag | Effect |
|------|--------|
| `--human` | Output `[mowmo]`-prefixed plain text instead of JSON |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Package not found |
| 2 | Dependency conflict |
| 3 | Permission denied |
| 4 | Network error |
| 5 | Disk space insufficient |
| 99 | Unknown error |

## Project Layout

```
Dockerfile              # Arch Linux base image with all Mohjave packages
.dockerignore           # Excludes specs/, .git/, etc. from build context
.github/workflows/      # GitHub Actions CI pipeline
Makefile                # build, test, push targets
mowmo/mowmo.sh         # Package manager CLI (6 commands, JSON output)
sdk/mcp-driver-spec.md  # MCP driver interface specification
tests/integration/      # Integration tests (run inside Docker)
LICENSE                 # GPL v3.0 + No-Competing-OS
```

## System Packages

The base image includes these package groups and why they exist:

| Category | Packages | Purpose |
|----------|----------|---------|
| Compositor | `cage` | Single-window Wayland kiosk for the Electron desktop |
| Display manager | `sddm` | Login manager |
| Audio | `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber` | PipeWire audio stack (voice daemon uses PipeWire for capture/playback). SPA plugins (`libspa`) are bundled in `pipewire`. |
| TTS | `espeak-ng` | Phonemization backend for Kokoro-82M TTS |
| Graphics | `mesa`, `vulkan-tools` | GPU drivers and diagnostics |
| Fonts | `ttf-jetbrains-mono`, `noto-fonts` | Monospace and fallback fonts. `ttf-rubik` (Mohjave primary UI font) is installed via AUR at ISO build time. |
| Electron deps | `nodejs`, `npm`, `gtk3`, `nss`, `alsa-lib`, `at-spi2-core`, `libdrm` | Runtime dependencies for the Electron desktop shell |
| LLM | `llama-server` (built from source, tag `b8508`) | Serves the mohwise-ankur-4b (Qwen3.5-4B fine-tune) model |
| Build support | `pkgconf`, `clang` | Kept in image for ISO step to compile the voice daemon (whisper-rs, ONNX Runtime) against PipeWire headers |
| System | `polkit`, `plymouth`, `networkmanager`, `openssh` | Privilege management, boot splash, networking |
| Utilities | `jq`, `curl`, `git`, `vim`, `sudo` | General tooling |

## CI/CD

Pushing to `main` triggers a GitHub Actions workflow that:
1. Builds the Docker image
2. Runs integration tests inside the container
3. Pushes to `registry.core.mohjave.com` with `:latest` and `:YYYY-MM-DD` tags

## License

GPL v3.0 with No-Competing-OS addendum. See [LICENSE](LICENSE).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure `shellcheck` passes with zero warnings on all `.sh` files
4. Ensure `make test` passes
5. Follow commit format: `type(scope): description`
   - Scopes: `mowmo`, `sdk`, `docker`, `ci`
6. Submit a pull request
