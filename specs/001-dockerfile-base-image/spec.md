# Feature Specification: Dockerfile + Arch Base Image to Registry

**Feature Branch**: `001-dockerfile-base-image`
**Created**: 2026-03-25
**Status**: Draft
**Input**: Jira MOH-367 — Create the Dockerfile that produces the Arch Linux base image for Mohjave, publish it to a container registry, include the mowmo package manager (Bash v1), and define the MCP driver interface specification.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build the Arch Linux Base Image (Priority: P1)

As a Mohjave developer, I want to build a container image from the Dockerfile that contains all required Arch Linux system packages, so that the ISO build pipeline has a reliable, reproducible foundation to layer on top of.

**Why this priority**: This is the core deliverable. Every downstream artifact (ISO build, developer environment, testing) depends on a working base image with the correct package set.

**Independent Test**: Can be fully tested by running `docker build .` in the repository root and verifying the image builds without errors and contains the expected packages.

**Acceptance Scenarios**:

1. **Given** the repository is cloned and Docker is available, **When** `docker build .` is run in the repo root, **Then** the image builds successfully with all specified packages installed.
2. **Given** the image is built, **When** `docker run mowmo:latest pacman -Q hyprland` is executed, **Then** the installed version of hyprland is returned.
3. **Given** the image is built, **When** `docker run mowmo:latest which llama-server` is executed, **Then** a valid path is returned.

---

### User Story 2 - Publish the Base Image to a Container Registry (Priority: P1)

As a Mohjave developer, I want the built base image pushed to a container registry, so that the ISO build pipeline and other developers can pull it without building locally.

**Why this priority**: Without registry availability the image cannot be consumed by the ISO build (MOH-356) or by other team members, blocking all downstream work.

**Independent Test**: Can be fully tested by pushing the image and then pulling it from a clean environment, verifying the pulled image matches the built one.

**Acceptance Scenarios**:

1. **Given** the image is built locally, **When** it is tagged and pushed to the target registry, **Then** the image is retrievable via `docker pull` from the registry URL.
2. **Given** the self-hosted registry is not yet available, **When** the interim registry (GitHub Container Registry) is used, **Then** the image is accessible at the interim registry URL.

---

### User Story 3 - Use mowmo to Manage Packages Inside the Image (Priority: P2)

As a Mohjave system component (the kernel/orchestrator), I want a CLI tool (`mowmo`) available inside the base image that wraps pacman/paru, so that packages can be installed, removed, searched, and updated through a unified interface.

**Why this priority**: The mowmo package manager is essential for the OS user experience, but the base image can exist and be useful without it. It adds the management layer on top of the foundation.

**Independent Test**: Can be fully tested by running `mowmo install firefox` inside a running container and verifying Firefox is installed.

**Acceptance Scenarios**:

1. **Given** a container running from the base image, **When** `mowmo install firefox` is executed, **Then** Firefox is installed via pacman.
2. **Given** a container running from the base image, **When** `mowmo remove firefox` is executed, **Then** Firefox is removed.
3. **Given** a container running from the base image, **When** `mowmo search editor` is executed, **Then** relevant package results are displayed.
4. **Given** a container running from the base image, **When** `mowmo update` is executed, **Then** system packages are updated.

---

### User Story 4 - Reference the MCP Driver Interface Specification (Priority: P3)

As a driver developer, I want a public specification document describing the MCP driver interface, so that I understand the contract my driver must fulfill (tool registration, transport format, health check, shutdown, token limits) without needing access to private implementation code.

**Why this priority**: The specification is a documentation artifact that enables future driver development. It has no runtime dependency and does not block image or mowmo functionality.

**Independent Test**: Can be tested by reviewing the specification document for completeness against the required sections (tool registration, stdio transport, health check, graceful shutdown, token ceiling).

**Acceptance Scenarios**:

1. **Given** the repository is cloned, **When** `sdk/mcp-driver-spec.md` is opened, **Then** it describes tool registration protocol, stdio transport format, health check protocol, graceful shutdown, and token ceiling per driver.

---

### User Story 5 - Ensure Repository Contains No Private Code (Priority: P2)

As a project maintainer, I want the public mowmo repository to contain no private MCP driver implementation code, so that intellectual property boundaries are maintained.

**Why this priority**: Security and IP protection are critical for a public repository. Leaking private code could have legal and competitive consequences.

**Independent Test**: Can be tested by searching the repository for any files from `crates/drivers/` or any MCP driver implementation code.

**Acceptance Scenarios**:

1. **Given** the repository is inspected, **When** a search is performed for files from `crates/drivers/` or driver implementation code, **Then** no such files or code are found.

---

### Edge Cases

- What happens when a package in the Dockerfile package list is unavailable or renamed in the Arch repositories? The build should fail explicitly with a clear error indicating which package is missing.
- What happens when `mowmo install` is given a package that exists only in the AUR? It should fall back to `paru` for AUR packages and succeed if `paru` is available.
- What happens when `mowmo install` is given a nonexistent package name? It should display an appropriate error message from the underlying package manager.
- What happens when the target container registry is unreachable during push? The process should fail with a clear connectivity error and provide guidance to use the interim registry.
- What happens when `mowmo update` is run with no network connectivity? It should fail gracefully with a meaningful error message.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST contain a Dockerfile at the root that builds a minimal Arch Linux image with all system packages required by Mohjave pre-installed.
- **FR-002**: The built image MUST include desktop environment packages (Hyprland, SDDM, portal utilities), audio stack (PipeWire, WirePlumber), GPU support (Mesa, Vulkan tools), fonts, networking (NetworkManager), and developer tools (rustup, Node.js, npm).
- **FR-003**: The built image MUST include `llama-cpp` for local LLM inference capability.
- **FR-004**: The built image MUST have locale configured to `en_US.UTF-8`.
- **FR-005**: The repository MUST contain a `.dockerignore` file to exclude unnecessary files from the build context.
- **FR-006**: The built image MUST be publishable to a container registry (self-hosted or GitHub Container Registry as interim) with both a `:latest` tag and a date-based tag (`:YYYY-MM-DD`) for reproducible downstream builds.
- **FR-007**: The repository MUST contain `mowmo/mowmo.sh`, a Bash script that wraps `pacman` and `paru` with subcommands: `install`, `remove`, `search`, and `update`.
- **FR-008**: `mowmo install <package>` MUST install the specified package using pacman (or paru for AUR packages). paru MUST be pre-installed in the base image to guarantee AUR support.
- **FR-009**: `mowmo remove <package>` MUST remove the specified package using pacman.
- **FR-010**: `mowmo search <query>` MUST search available packages and display results.
- **FR-011**: `mowmo update` MUST perform a full system update via pacman.
- **FR-012**: The repository MUST contain `sdk/mcp-driver-spec.md` describing the MCP driver interface: tool registration protocol, stdio transport format (JSON lines), health check protocol, graceful shutdown (SIGTERM), and token ceiling per driver.
- **FR-013**: The repository MUST NOT contain any MCP driver implementation code (no files from `crates/drivers/`).
- **FR-014**: The repository MUST contain a LICENSE file with GPL v3.0 and the No-Competing-OS addendum clause.
- **FR-015**: The repository MUST contain a README.md describing the project purpose and usage.
- **FR-016**: All mowmo subcommands MUST produce structured JSON output by default (machine-first format) with a documented JSON schema, to support direct deserialization by the kernel/orchestrator.
- **FR-017**: All mowmo subcommands MUST support a `--human` flag that outputs human-readable text for developer debugging.

### Key Entities

- **Base Image**: The Docker container image built from Arch Linux with all Mohjave system packages pre-installed. Serves as the foundation for the ISO build pipeline.
- **mowmo**: A Bash-based package manager wrapper providing a unified CLI interface over pacman and paru for package management operations.
- **MCP Driver Spec**: A documentation artifact defining the interface contract that MCP drivers must implement, including transport, lifecycle, and resource constraints.
- **Container Registry**: The destination where built images are published for consumption by downstream pipelines and developers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The base image builds successfully from a clean clone of the repository in under 15 minutes on a standard CI runner.
- **SC-002**: All specified system packages are present and queryable inside the built image.
- **SC-003**: The image is pullable from the container registry by any developer or CI pipeline with appropriate access.
- **SC-004**: The mowmo package manager successfully installs, removes, searches, and updates packages inside the running image.
- **SC-005**: The MCP driver specification document covers all five required interface areas (tool registration, stdio transport, health check, graceful shutdown, token ceiling).
- **SC-006**: A repository audit confirms zero private implementation code is present.
- **SC-007**: The LICENSE file contains both the GPL v3.0 text and the No-Competing-OS addendum.

## Clarifications

### Session 2026-03-25

- Q: Should paru (AUR helper) be pre-installed in the base image during Docker build? → A: Yes — paru MUST be pre-installed in the image. AUR support is essential (VS Code, Spotify, Discord, Chrome are all AUR). The Dockerfile should create a build user, clone paru, build via makepkg, and clean up artifacts.
- Q: Should mowmo output be plain text or structured JSON for kernel consumption? → A: Structured JSON is the default output for all subcommands. A `--human` flag is available for developer debugging. Full JSON schema for all commands is documented so the orchestrator's PackageInstallWorker can `serde_json::from_str` the output directly.
- Q: What image tagging strategy should be used for the container registry? → A: `:latest` plus date-based tags (e.g., `:2026-03-25`). Semver is meaningless on a rolling-release base. Date tags let the ISO build pin to a known-good image.

## Assumptions

- Docker (or a compatible container runtime) is available in the build environment.
- The Arch Linux base image (`archlinux:latest`) is accessible from public container registries.
- The exact package list in the Dockerfile may be refined during implementation; the specification captures the intent and categories of packages required.
- `paru` (AUR helper) MUST be pre-installed in the base image during Docker build (create build user, clone, makepkg -si, clean artifacts).
- The self-hosted registry (`registry.core.mohjave.com`) may not be available at initial implementation time; GitHub Container Registry (`ghcr.io/mohjave-os/mowmo`) serves as a viable interim target.
- Natural language interpretation of package requests is handled by the LLM kernel, not by mowmo itself — mowmo only accepts explicit package names.
- The MCP driver spec is a documentation-only artifact; no runtime implementations are included in this repository.
- This repository does not create the ISO build pipeline (handled by MOH-356 in the mohjave repo).
