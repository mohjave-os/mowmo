# Quickstart: Dockerfile + Arch Base Image to Registry

**Feature**: 001-dockerfile-base-image

## Prerequisites

- Docker (or compatible container runtime)
- Git
- jq (installed inside the image; needed for mowmo JSON output)

## Build the Image

```bash
git clone https://github.com/mohjave-os/mowmo.git
cd mowmo
docker build -t mowmo:latest .
```

## Verify the Image

```bash
# Check a key package is installed
docker run --rm mowmo:latest pacman -Q hyprland

# Check llama-server is available
docker run --rm mowmo:latest which llama-server

# Check paru is available
docker run --rm mowmo:latest paru --version
```

## Use mowmo Inside the Image

```bash
# Start a container
docker run --rm -it mowmo:latest bash

# Inside the container — JSON output (default)
mowmo search editor
mowmo install firefox
mowmo info firefox
mowmo list
mowmo update
mowmo remove firefox

# Human-readable output
mowmo install firefox --human
```

## Run Tests

```bash
make test
```

This builds the image (if not already built) and runs integration tests inside a container.

## Push to Registry

```bash
# Tag with date
DATE=$(date +%Y-%m-%d)
docker tag mowmo:latest registry.core.mohjave.com/mowmo:latest
docker tag mowmo:latest registry.core.mohjave.com/mowmo:${DATE}

# Login and push
docker login registry.core.mohjave.com
docker push registry.core.mohjave.com/mowmo:latest
docker push registry.core.mohjave.com/mowmo:${DATE}
```

In CI (GitHub Actions), this is automated — push to `main` triggers build and push with both `:latest` and `:YYYY-MM-DD` tags.

## Project Layout

```text
Dockerfile           # Arch Linux base image with all Mohjave packages
.dockerignore        # Excludes specs/, .git/, etc. from build context
.github/workflows/   # GitHub Actions CI pipeline
Makefile             # build, test, push targets
mowmo/mowmo.sh      # Package manager CLI (6 commands, JSON output)
sdk/mcp-driver-spec.md  # MCP driver interface specification
tests/integration/   # Integration tests (run inside Docker)
LICENSE              # GPL v3.0 + No-Competing-OS
README.md            # Project overview
```
