# Research: Dockerfile + Arch Base Image to Registry

**Date**: 2026-03-25
**Feature**: 001-dockerfile-base-image

## R1: Installing paru (AUR helper) in Docker

**Decision**: Install paru during Docker build using a temporary non-root build user.

**Rationale**: makepkg cannot run as root (Arch Linux security restriction). A temporary build user with passwordless sudo is the standard pattern. Build artifacts are cleaned up in the same layer to minimize image bloat.

**Dockerfile pattern**:

```dockerfile
# Create build user for makepkg (cannot run as root)
RUN useradd -m -G wheel builduser && \
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builduser && \
    chmod 0440 /etc/sudoers.d/builduser

# Install paru as build user
USER builduser
WORKDIR /home/builduser
RUN git clone https://aur.archlinux.org/paru.git && \
    cd paru && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf paru .cargo .cache

# Return to root
USER root
WORKDIR /root
```

**Key requirements**:

- `base-devel` and `git` must be installed before paru build
- `sudo` must be installed and builduser added to wheel group
- Passwordless sudo via `/etc/sudoers.d/builduser` (makepkg -si needs it)
- Clean up `/home/builduser/paru`, `.cargo`, `.cache` after build
- Typical build time overhead: 2-5 minutes (Rust compilation)

**Alternatives considered**:

- Multi-stage build (copy paru binary from builder stage) — rejected because paru has runtime dependencies on pacman/libalpm that are complex to copy correctly
- Pre-built paru binary from GitHub releases — rejected because version pinning creates maintenance burden on a rolling-release base

## R2: GitHub Actions Workflow for Registry Push

**Decision**: Use official Docker GitHub Actions with htpasswd credentials from repo secrets to push to `registry.core.mohjave.com`.

**Rationale**: Official Docker actions handle edge cases (BuildKit caching, tag generation). The self-hosted registry at `registry.core.mohjave.com` uses htpasswd authentication — credentials are stored in GitHub repo secrets as `REGISTRY_HTPASSWD_USER` and `REGISTRY_HTPASSWD_PASS`.

**Workflow structure**:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: registry.core.mohjave.com
          username: ${{ secrets.REGISTRY_HTPASSWD_USER }}
          password: ${{ secrets.REGISTRY_HTPASSWD_PASS }}

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: registry.core.mohjave.com/mowmo
          tags: |
            type=raw,value=latest
            type=raw,value={{date 'YYYY-MM-DD'}}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Key details**:

- `docker/metadata-action` has built-in date templating: `{{date 'YYYY-MM-DD'}}` — no manual date calculation
- BuildKit cache (`cache-from: type=gha`) speeds up rebuilds significantly
- Authentication via `REGISTRY_HTPASSWD_USER` / `REGISTRY_HTPASSWD_PASS` secrets (already configured)
- Image name: `registry.core.mohjave.com/mowmo`

**Alternatives considered**:

- GitHub Container Registry (ghcr.io) — rejected by user; self-hosted registry is the target
- Woodpecker CI — rejected by user; this is a public GitHub repo
- Manual `docker build && docker push` — rejected; official actions handle caching and tag generation

## R3: Bash JSON Output Patterns

**Decision**: Use `jq` for JSON construction. Buffer output and emit a single JSON object at command completion.

**Rationale**: jq provides type-safe JSON construction with proper escaping. The kernel orchestrator deserializes output with `serde_json::from_str()` — malformed JSON would cause a Rust panic. Buffered output matches the atomic result model expected by the orchestrator's workers.

**JSON construction approach**:

```bash
# Use jq --arg for safe string interpolation (handles all escaping)
jq -n \
  --arg package "$package" \
  --arg version "$version" \
  --arg status "success" \
  '{command: "install", package: $package, version: $version, status: $status}'
```

**Output routing**:

- **stdout**: JSON object (machine-readable, parsed by kernel)
- **stderr**: Plain text `[mowmo]`-prefixed messages (human debugging, not parsed)
- **exit code**: Numeric status per constitution Art. III.3 (0=success, 1=not found, 2=conflict, 3=permission, 4=network, 5=disk, 99=unknown)

**Error reporting**: Both exit code AND JSON error object on stdout:

```json
{"command": "install", "package": "notreal", "status": "failed", "error": "Package not found", "exit_code": 1}
```

The kernel needs both: exit code for fast failure detection, JSON for error details to feed back to the LLM.

**`--human` flag**: When set, output uses `[mowmo]` prefixed lines per constitution Art. III.4 instead of JSON. Errors still go to stderr.

**Alternatives considered**:

- printf/heredoc for JSON — rejected; unsafe with package names containing quotes, newlines, or Unicode
- JSON Lines streaming by default — rejected; adds complexity for v1, kernel expects single result
- Errors to stderr as JSON — rejected; kernel only parses stdout
