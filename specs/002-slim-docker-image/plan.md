# Implementation Plan: Slim Docker Base Image

**Branch**: `002-slim-docker-image` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-slim-docker-image/spec.md`

## Summary

Strip all obsolete packages from the mowmo Dockerfile after the Electron + cage compositor pivot. Remove Hyprland, WebKitGTK, build tools, and Hyprland ecosystem tools. Add cage compositor. Build paru from source with same-layer build tool cleanup (paru-bin rejected due to libalpm version mismatch). Install llama.cpp-bin (pre-compiled) via paru. Target Docker image filesystem under 3.5GB (excluding model).

## Technical Context

**Language/Version**: Dockerfile (Arch Linux base), Bash (v1) for scripts
**Primary Dependencies**: pacman (official repos), paru (AUR helper, built from source), makepkg
**Storage**: N/A
**Testing**: Integration tests run inside Docker container via `make test`
**Target Platform**: x86_64 Linux (Arch Linux Docker image)
**Project Type**: Docker base image (OS foundation for ISO builds)
**Performance Goals**: Image filesystem under 3.5GB (excluding LLM model). Actual: 3.0GB filesystem.
**Constraints**: Must retain all runtime packages; must not break existing integration tests
**Scale/Scope**: Single Dockerfile, ~75 lines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Article | Status | Notes |
|------|---------|--------|-------|
| Scope boundary | Art. II | PASS | Dockerfile is one of mowmo's three owned things |
| No proprietary code | Art. VIII §8.2 | PASS | No kernel, orchestrator, or private repo content |
| Engineering standards | Art. VI §6.1 | PASS | Dockerfile changes; Bash scripts follow `set -euo pipefail` |
| Testing requirement | Art. VI §6.3 | PASS | Existing integration tests must pass; Docker build is the primary test |
| Commit format | Art. VI §6.4 | PASS | Will use `chore(docker): ...` format |
| Docker image contents | Art. V §5.3 | UPDATE NEEDED | §5.3 lists current packages — constitution should be updated after this feature lands |

**Post-Phase 1 re-check**: All gates still pass. No new violations introduced by research decisions (paru source build with same-layer cleanup, llama.cpp-bin, cage from official repos).

## Project Structure

### Documentation (this feature)

```text
specs/002-slim-docker-image/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
Dockerfile               # PRIMARY: rewrite package lists and AUR build strategy
tests/
└── integration/         # Existing tests — verify they still pass
```

**Structure Decision**: This feature modifies a single file (Dockerfile) at the repository root. No new source directories or files are created. The existing `tests/integration/` tests must continue to pass with the updated image.

## Complexity Tracking

No constitution violations to justify. This is a straightforward Dockerfile package list update with a build strategy change (same-layer install/remove of build tools, switch to llama.cpp-bin).
