# mowmo Development Guidelines

## What This Is

mowmo is the Arch Linux base Docker image and package manager CLI for Mohjave OS.
The Dockerfile produces an image with all runtime packages pre-installed.
The `mowmo` CLI wraps pacman/paru with structured JSON output for the kernel orchestrator.

## Active Technologies

- **Base image**: Arch Linux (Docker), with pacman (official repos) and paru (AUR helper)
- **CLI**: Bash, shellcheck-compliant (`set -euo pipefail`), JSON output via jq
- **Compositor**: cage (single-window Wayland kiosk)
- **Audio**: PipeWire + WirePlumber (voice daemon builds against PipeWire at ISO stage)
- **TTS**: Kokoro-82M (ONNX Runtime) with espeak-ng for phonemization
- **Voice input**: whisper-rs (built at ISO stage, not in this image)
- **LLM**: llama-server built from source (tag b8508), serves mohwise-ankur-4b (Qwen3.5-4B fine-tune)
- **Desktop**: Electron app (sole GUI, launched inside cage)
- **Build tools in image**: clang, pkgconf (retained for ISO voice-daemon compilation)

## Project Structure

```text
Dockerfile              # Arch Linux base image with all Mohjave runtime packages
mowmo/mowmo.sh         # Package manager CLI (6 commands, JSON output)
sdk/mcp-driver-spec.md  # MCP driver interface specification
tests/integration/      # Integration tests (run inside Docker via make test)
Makefile                # build, test, push targets
```

## Commands

```bash
make build          # Build Docker image
make test           # Run integration tests inside container
make push           # Push to registry
mowmo install <pkg> # Install package (pacman, falls back to AUR)
mowmo remove <pkg>  # Remove package
mowmo search <q>    # Search repos
mowmo update        # Full system update
mowmo list          # List installed packages
mowmo info <pkg>    # Package details
```

## Code Style

- Bash: `set -euo pipefail`, shellcheck-clean, no warnings
- Dockerfile: one logical section per RUN, comments explain "why" not "what"
- Commit format: `type(scope): description` (scopes: mowmo, sdk, docker, ci)

## Key Details

- llama.cpp is built from source (not AUR) because the AUR package uses shared backend plugins that fail in containers
- Build deps (cmake, make) are cleaned after llama.cpp build; clang/pkgconf are kept for ISO voice-daemon compilation
- ttf-rubik is NOT in official Arch repos; installed via AUR (paru) during ISO build, not in this Dockerfile
- libspa is bundled inside the pipewire package on Arch (no separate package needed)
- espeak-ng is required by Kokoro-82M for phonemization and must be in the base image

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
