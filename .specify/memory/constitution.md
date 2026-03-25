# MOWMO CONSTITUTION

**Version:** 1.0
**Ratified:** 2026-03-25
**Maintainer:** Mohjave OS (mohjave-os)

---

## Article I — Identity

mowmo is the natural language package manager for Mohjave OS. It is the public interface between the user's intent and the system's packages. When a user says "install something for editing photos," the LLM translates that into `mowmo install gimp`. mowmo executes the concrete command.

mowmo is NOT an AI. It does not interpret natural language. It does not make decisions. It is a thin, reliable, predictable execution layer that wraps the system package manager. The intelligence lives in the kernel. mowmo is the hands.

**Repository:** `mohjave-os/mowmo` (PUBLIC)
**Website:** www.mohjave.com

---

## Article II — Scope

mowmo owns exactly three things:

1. **Package management CLI** — a wrapper around `pacman` and `paru` that provides a consistent interface for the Mohjave kernel's orchestrator to call
2. **MCP Driver Interface Spec** — the public specification that third-party MCP drivers must implement to integrate with Mohjave OS
3. **Arch Linux base image** — the Dockerfile that produces the foundation image for Mohjave ISO builds

mowmo does NOT own: the kernel, the orchestrator, the shell, the safety governor, MCP driver implementations, model files, or any proprietary Mohjave component. Those live in the private `mohjave-os/mohjave` repository.

---

## Article III — Architecture

### 3.1 Package Manager (mowmo CLI)

```
Kernel Orchestrator
    |
    v
PackageInstallWorker / PackageRemoveWorker / PackageSearchWorker
    |
    v
mowmo install <package>    (called as a subprocess)
    |
    v
pacman -S --noconfirm <package>    (or paru -S for AUR)
```

mowmo is invoked as a CLI tool by the kernel's worker processes. It is never called directly by the user (the user talks to moh, moh talks to the orchestrator, the orchestrator calls mowmo).

**v1 implementation:** Bash script (`mowmo/mowmo.sh`)
**Future:** Rust binary with structured output, dependency resolution, rollback support

### 3.2 Supported Commands

| Command | Behaviour |
|---------|-----------|
| `mowmo install <package>` | Install via pacman. Fall back to paru for AUR packages. |
| `mowmo remove <package>` | Remove via pacman. |
| `mowmo search <query>` | Search repos via pacman. Return structured results. |
| `mowmo update` | Full system update via pacman -Syu. |
| `mowmo list` | List installed packages. |
| `mowmo info <package>` | Show package details. |

### 3.3 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Package not found |
| 2 | Dependency conflict |
| 3 | Permission denied (not root) |
| 4 | Network error |
| 5 | Disk space insufficient |
| 99 | Unknown error |

The orchestrator's PackageInstallWorker reads the exit code to determine success or failure. Non-zero exit codes include a stderr message that the evaluator can feed back to the LLM for correction.

### 3.4 Output Format

All mowmo commands write structured output to stdout:

```
[mowmo] install firefox
[mowmo] resolving dependencies...
[mowmo] installing firefox (127.0.2-1)...
[mowmo] done: firefox installed successfully
```

Lines prefixed with `[mowmo]` can be parsed by the orchestrator's worker to extract status. Future versions will support `--json` flag for machine-readable output.

---

## Article IV — MCP Driver Interface Spec

The MCP (Model Context Protocol) driver interface defines how third-party tools integrate with Mohjave OS. This specification lives at `sdk/mcp-driver-spec.md` and is the public contract.

### 4.1 What a Driver Is

A driver is a standalone process that exposes one or more tools to the Mohjave kernel. The kernel communicates with drivers via stdio (JSON lines on stdin/stdout). Drivers are NOT libraries — they are executables.

### 4.2 Registration Protocol

On startup, a driver writes a registration message to stdout:

```json
{"type": "register", "tools": [
  {"name": "weather_get", "description": "Get current weather for a city", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}
]}
```

The kernel reads this, registers the tools, and begins sending tool call requests.

### 4.3 Tool Call Protocol

Kernel sends to driver's stdin:

```json
{"type": "tool_call", "id": "call_001", "name": "weather_get", "arguments": {"city": "Berlin"}}
```

Driver writes response to stdout:

```json
{"type": "tool_result", "id": "call_001", "content": "Berlin: 12°C, partly cloudy"}
```

### 4.4 Health Check

Kernel periodically sends:

```json
{"type": "health_check"}
```

Driver must respond within 5 seconds:

```json
{"type": "health_ok"}
```

If no response, the kernel marks the driver as unhealthy and stops routing tool calls to it.

### 4.5 Graceful Shutdown

Kernel sends SIGTERM. Driver has 10 seconds to finish in-progress work and exit. After 10 seconds, kernel sends SIGKILL.

### 4.6 Constraints

- One driver process per tool namespace
- Maximum 10 tools per driver
- Maximum 60 second execution time per tool call
- Token ceiling: driver response must not exceed 4,096 tokens
- No network access unless explicitly declared in the tool manifest
- Drivers run in a systemd-nspawn sandbox (configured by the kernel, not the driver)

---

## Article V — Docker Base Image

### 5.1 Purpose

The Dockerfile at the repo root produces an Arch Linux image containing all system packages Mohjave needs. The private mohjave repo's ISO build pipeline pulls `FROM` this image and layers on the compiled kernel binary, Electron desktop app, mohwise model, and config files.

### 5.2 Image Target

Primary: `registry.core.mohjave.com/mowmo:latest`
Interim: `ghcr.io/mohjave-os/mowmo:latest`

### 5.3 What the Image Contains

- Arch Linux base (base, linux, linux-firmware)
- Boot (grub, efibootmgr)
- Networking (networkmanager, openssh)
- Wayland compositor (cage — single-window kiosk compositor for Electron desktop)
- Login manager (sddm)
- Audio (pipewire, pipewire-pulse, pipewire-alsa, wireplumber)
- Graphics (mesa, vulkan-tools)
- Fonts (ttf-jetbrains-mono, noto-fonts)
- LLM inference (llama.cpp-bin via AUR)
- AUR support (paru — built from source, build tools removed in same Docker layer)
- System services (polkit, plymouth)
- Utilities (jq)

### 5.4 What the Image Does NOT Contain

- Compiled Mohjave binaries (mohjave-kernel, mohjave-shell)
- Model files (mohwise-ankur-*.gguf)
- Config files (/etc/mohjave/)
- MCP driver implementations
- User data
- Proprietary code of any kind

The image is a clean Arch base. Everything Mohjave-specific is added by the ISO build pipeline.

---

## Article VI — Engineering Standards

### 6.1 Language (v1)

mowmo v1 is Bash. Future versions will be Rust.

Bash rules:
- `set -euo pipefail` at the top of every script
- No unquoted variables
- No `eval`
- No `curl | sh`
- All functions documented with a one-line comment
- shellcheck must pass with zero warnings

### 6.2 Language (future: Rust)

When mowmo is rewritten in Rust:
- `cargo fmt` — mandatory
- `cargo clippy` — zero warnings
- `cargo test` — all tests pass
- `thiserror` for error types
- `serde` for JSON serialization
- No `unwrap()` in production code

### 6.3 Testing

- Every mowmo command has at least one integration test
- Tests run inside the Docker image (not on the host)
- `make test` runs the full suite
- CI must pass before merge

### 6.4 Commit Messages

Format: `type(scope): description`

Types: feat, fix, docs, test, chore, refactor
Scopes: mowmo, sdk, docker, ci

Examples:
- `feat(mowmo): add mowmo info command`
- `fix(docker): pin llama-cpp version to avoid breakage`
- `docs(sdk): clarify health check timeout`

---

## Article VII — Licensing

### 7.1 Licence

GNU General Public License v3.0 with the following additional restriction:

> You may not use this software to create, distribute, or operate an operating system that competes with Mohjave OS without written permission from Mohjave OS.

### 7.2 What This Means

- You CAN use mowmo in your own projects (non-OS)
- You CAN fork and modify mowmo for personal use
- You CAN contribute to mowmo under GPL terms
- You CANNOT use mowmo to build a competing operating system
- You CANNOT strip the No-Competing-OS clause from derivative works

### 7.3 Contributor Agreement

By submitting a pull request, you agree that your contribution is licensed under the same GPL + No-Competing-OS terms.

---

## Article VIII — Boundaries

### 8.1 What Goes in mowmo (Public Repo)

- Package manager CLI source code
- MCP driver interface specification
- Dockerfile for Arch base image
- Documentation for contributors and driver developers
- Integration tests
- CI configuration

### 8.2 What NEVER Goes in mowmo

- Mohjave kernel source code
- Orchestrator, planner, executor, evaluator code
- Safety governor or allowlist
- IPC protocol implementation
- Shell/UI code
- Model files or training data
- MCP driver implementations (those are private)
- Auth secrets, API keys, or credentials
- User data schemas or privacy-sensitive structures
- Any file from `mohjave-os/mohjave` private repo

### 8.3 Enforcement

Every PR is reviewed against this boundary. Code that belongs in the private repo is rejected. If in doubt, it goes private.

---

## Article IX — Contribution Guidelines

### 9.1 Who Can Contribute

Anyone. mowmo is a public GPL project. We welcome contributions from the community.

### 9.2 How to Contribute

1. Fork the repo
2. Create a branch: `feat/your-feature` or `fix/your-fix`
3. Write code following Article VI standards
4. Write or update tests
5. Submit a pull request with a clear description
6. Wait for review — we aim to respond within 48 hours

### 9.3 What We Look For in PRs

- Does it follow engineering standards (Article VI)?
- Does it respect the boundaries (Article VIII)?
- Does it have tests?
- Is the commit message properly formatted?
- Does CI pass?

### 9.4 What We Will Reject

- Code that belongs in the private repo
- PRs that introduce cloud dependencies
- PRs that weaken the GPL + No-Competing-OS licence
- PRs without tests for new functionality
- PRs that break existing tests

---

## Article X — Versioning

mowmo follows semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to the mowmo CLI interface or MCP driver spec
- **MINOR**: New commands, new spec fields, new Docker packages
- **PATCH**: Bug fixes, documentation updates, security patches

The Docker image is tagged with the mowmo version: `mowmo:1.0.0`, `mowmo:1.1.0`, etc. The `latest` tag always points to the most recent stable release.

---

## Article XI — Relationship to Mohjave

mowmo exists to serve Mohjave OS. It is a public building block of a proprietary product. This dual nature is intentional:

- The package manager interface is public so the community can contribute, audit, and trust it
- The MCP driver spec is public so third-party developers can build integrations
- The Docker base image is public so the build process is transparent

But the intelligence — the kernel, the orchestrator, the safety layer, the model — is private. mowmo is the open hand of a proprietary brain.

This is not contradictory. It is the same model Redis, Docker, and GitLab used to build billion-dollar companies on open-source foundations.

---

*This Constitution is the governing document for the mohjave-os/mowmo repository. All code, documentation, and contributions must comply with it. Amendments require approval from the Mohjave OS maintainer.*