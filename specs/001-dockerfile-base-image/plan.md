# Implementation Plan: Dockerfile + Arch Base Image to Registry

**Branch**: `001-dockerfile-base-image` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-dockerfile-base-image/spec.md`

## Summary

Create the `mohjave-os/mowmo` repository contents: a Dockerfile producing an Arch Linux base image with all Mohjave system packages (including paru for AUR support), the mowmo v1 Bash CLI with 6 commands outputting structured JSON by default, the MCP driver interface specification, GPL + No-Competing-OS licensing, and a GitHub Actions workflow that builds, tests, and pushes the image to `registry.core.mohjave.com` with `:latest` and date-based tags.

## Technical Context

**Language/Version**: Bash (v1), shellcheck-compliant (`set -euo pipefail`)
**Primary Dependencies**: pacman, paru, jq (for JSON output in Bash)
**Storage**: N/A
**Testing**: Integration tests run inside Docker image via `make test`
**Target Platform**: Arch Linux (Docker container), GitHub Actions CI
**Project Type**: CLI + Docker image + documentation
**Performance Goals**: Docker build < 15 minutes on GitHub Actions runner
**Constraints**: shellcheck zero warnings, no eval, no unquoted variables, no curl|sh, all functions documented
**Scale/Scope**: Single Dockerfile, single CLI script (~6 commands), one CI pipeline

**CI/Registry Details**:

- CI system: GitHub Actions (`.github/workflows/build.yml`)
- Registry: `registry.core.mohjave.com` (htpasswd auth)
- Credentials: `REGISTRY_HTPASSWD_USER` and `REGISTRY_HTPASSWD_PASS` (already in GitHub repo secrets)
- Image tags: `:latest` + date-based (`:YYYY-MM-DD`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Scope compliance** (Art. II) — PASS: Feature covers all 3 owned items: CLI, MCP spec, Docker image
- **No private code** (Art. VIII) — PASS: No kernel, orchestrator, driver impl, model files, or mohjave-repo content
- **Bash standards** (Art. VI.1) — PASS: Plan requires set -euo pipefail, shellcheck, no eval, no unquoted vars
- **Testing** (Art. VI.3) — PASS: Integration tests in Docker, make test, CI must pass
- **Commit format** (Art. VI.4) — PASS: type(scope): description format will be followed
- **Licensing** (Art. VII) — PASS: GPL v3.0 + No-Competing-OS clause
- **mowmo commands** (Art. III.2) — PASS: All 6 commands: install, remove, search, update, list, info
- **Exit codes** (Art. III.3) — PASS: Exit codes 0-5, 99 per constitution
- **Output format** (Art. III.4) — NOTE: Constitution describes `[mowmo]` prefix; spec clarification decided JSON default with `--human` flag. `--human` mode uses the `[mowmo]` prefix format from constitution.

**Result**: All gates PASS. Output format evolution (JSON default) is a deliberate design decision from clarification, not a violation.

## Project Structure

### Documentation (this feature)

```text
specs/001-dockerfile-base-image/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── mowmo-cli.md
└── tasks.md             # Created by /speckit.tasks
```

### Source Code (repository root)

```text
mowmo/
├── Dockerfile
├── .dockerignore
├── .github/
│   └── workflows/
│       └── build.yml      # GitHub Actions: build, test, push to registry.core.mohjave.com
├── LICENSE
├── README.md
├── Makefile
├── mowmo/
│   ├── mowmo.sh           # v1 Bash CLI (6 commands, JSON default output)
│   └── README.md
├── sdk/
│   └── mcp-driver-spec.md
└── tests/
    └── integration/
        ├── run-tests.sh    # Test runner (executes inside Docker image)
        ├── test_install.sh
        ├── test_remove.sh
        ├── test_search.sh
        ├── test_update.sh
        ├── test_list.sh
        └── test_info.sh
```

**Structure Decision**: Flat single-project layout. No src/ indirection — the CLI is a single Bash script, the Dockerfile is at root, tests are integration-only and run inside the Docker image. This matches the project's nature as infrastructure tooling.

## Complexity Tracking

No constitution violations to justify. The plan is minimal and direct.
