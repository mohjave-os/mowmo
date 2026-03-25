# Feature Specification: Slim Docker Base Image

**Feature Branch**: `002-slim-docker-image`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: "MOH-392 — Strip bloated packages from mowmo Docker base image, add cage, target sub-4GB ISO. Only changes required for mowmo."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remove Obsolete Packages from Docker Image (Priority: P1)

As a Mohjave developer building the Docker base image, I want all packages that are no longer needed after the pivot to Electron + cage compositor to be removed from the Dockerfile, so that the resulting image is lean and contains only runtime-necessary packages.

**Why this priority**: The primary goal of this feature is to reduce image bloat. Removing Hyprland, Tauri/WebKitGTK, build tools, and Hyprland ecosystem tools is the single biggest impact — estimated ~950MB-1.2GB savings.

**Independent Test**: Can be verified by building the Docker image and confirming that removed packages (hyprland, webkit2gtk-4.1, rustup, base-devel, nodejs, npm, grim, slurp, dunst, xdg-desktop-portal-hyprland) are not present. Note: xdg-utils remains as a transitive dependency of sddm→qt6-base.

**Acceptance Scenarios**:

1. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q hyprland 2>&1` is run, **Then** it returns "not found"
2. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q webkit2gtk-4.1 2>&1` is run, **Then** it returns "not found"
3. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q rustup 2>&1` is run, **Then** it returns "not found"
4. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q base-devel 2>&1` is run, **Then** it returns "not found"
5. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q nodejs 2>&1` is run, **Then** it returns "not found"
6. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q npm 2>&1` is run, **Then** it returns "not found"
7. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q grim 2>&1` is run, **Then** it returns "not found"
8. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q slurp 2>&1` is run, **Then** it returns "not found"
9. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q dunst 2>&1` is run, **Then** it returns "not found"

---

### User Story 2 - Add cage Compositor Package (Priority: P1)

As a Mohjave developer, I want the cage Wayland compositor added to the Docker base image so that the Electron desktop app can run in a single-window kiosk-style Wayland session.

**Why this priority**: cage is the replacement compositor for Hyprland — removing Hyprland without adding cage would break the display pipeline.

**Independent Test**: Can be verified by building the Docker image and confirming cage is installed and executable.

**Acceptance Scenarios**:

1. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest which cage` is run, **Then** it returns a valid path (e.g., `/usr/bin/cage`)
2. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q cage` is run, **Then** it returns the installed version

---

### User Story 3 - Remove calamares Installer (Priority: P2)

As a Mohjave developer, I want calamares removed from the Docker base image because the alpha release targets live USB only (no installer needed), and calamares pulls in heavy Qt dependencies (~100MB+).

**Why this priority**: Significant size savings but lower than the main package removal. The alpha does not need an installer.

**Independent Test**: Can be verified by building the Docker image and confirming calamares is not present.

**Acceptance Scenarios**:

1. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q calamares 2>&1` is run, **Then** it returns "not found"

---

### User Story 4 - Eliminate Build Tools from Final Image (Priority: P2)

As a Mohjave developer, I want paru built from source with build tools (rustup, base-devel) removed in the same Docker layer, so that the Rust toolchain and C/C++ build tools do not persist in the final image.

**Why this priority**: Build tools add ~700MB of dead weight at runtime. Building paru from source and cleaning up in the same layer keeps paru functional while eliminating the toolchain. Note: paru-bin (pre-compiled) was rejected due to libalpm shared library version mismatches on Arch's rolling release.

**Independent Test**: Can be verified by building the Docker image and confirming paru is available as a command, and rustup/base-devel are not installed.

**Acceptance Scenarios**:

1. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest which paru` is run, **Then** it returns a valid path
2. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q rustup 2>&1` is run, **Then** it returns "not found"

---

### User Story 5 - Verify Retained Packages Are Present (Priority: P1)

As a Mohjave developer, I want to confirm that all packages that must be retained (core system, audio, graphics, fonts, LLM inference, login/boot, AUR support, and jq) remain installed after the cleanup.

**Why this priority**: Removing the wrong packages would break the system. Verification that essential packages survive is as important as the removals.

**Independent Test**: Can be verified by building the Docker image and running pacman queries against each retained package.

**Acceptance Scenarios**:

1. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q pipewire` is run, **Then** it returns the installed version
2. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q sddm` is run, **Then** it returns the installed version
3. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest which llama-server` is run, **Then** it returns a valid path
4. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q mesa` is run, **Then** it returns the installed version
5. **Given** the updated Dockerfile is built, **When** `docker run mowmo:latest pacman -Q jq` is run, **Then** it returns the installed version

---

### Edge Cases

- What happens if cage is not available in the Arch Linux official repositories? It must be installed from AUR via paru instead. (Resolved: cage is in the official `extra` repo.)
- What happens if paru-bin has library version mismatches? Build paru from source instead and remove build tools in the same Docker layer. (Resolved: paru-bin failed due to libalpm.so version mismatch; paru is built from source with same-layer cleanup.)
- What happens if a removed package is a transitive dependency of a retained package? It remains installed. (Resolved: xdg-utils is a transitive dependency of sddm→qt6-base and cannot be removed.)
- What happens if llama.cpp-bin has similar version mismatches to paru-bin? Install it via paru while base-devel is still available in the same build layer, before cleanup. (Resolved: llama.cpp-bin installed successfully via paru in the same layer.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Dockerfile MUST remove all Hyprland ecosystem packages (hyprland, xdg-desktop-portal-hyprland). Note: xdg-utils is a transitive dependency of sddm→qt6-base and cannot be removed without removing sddm.
- **FR-002**: The Dockerfile MUST remove all Tauri/WebKitGTK packages (webkit2gtk-4.1)
- **FR-003**: The Dockerfile MUST remove all build-only tools from the final image (rustup, base-devel, npm, nodejs)
- **FR-004**: The Dockerfile MUST remove all Hyprland-specific tool packages (grim, slurp, dunst)
- **FR-005**: The Dockerfile MUST remove calamares and its dependencies
- **FR-006**: The Dockerfile MUST add the cage Wayland compositor package
- **FR-007**: The Dockerfile MUST build paru from source and remove build tools (rustup, base-devel) in the same Docker layer so they do not persist in the final image. Note: paru-bin (pre-compiled) was rejected due to libalpm version mismatches on Arch's rolling release.
- **FR-008**: The Dockerfile MUST retain all core system packages (base, linux, linux-firmware, grub, efibootmgr, networkmanager, openssh, git, sudo, vim)
- **FR-009**: The Dockerfile MUST retain all audio packages (pipewire, pipewire-pulse, pipewire-alsa, wireplumber)
- **FR-010**: The Dockerfile MUST retain all graphics packages (mesa, vulkan-tools)
- **FR-011**: The Dockerfile MUST retain all font packages (ttf-jetbrains-mono, noto-fonts)
- **FR-012**: The Dockerfile MUST retain LLM inference capability via llama.cpp-bin (pre-compiled binary package from AUR)
- **FR-013**: The Dockerfile MUST retain system service packages (sddm, polkit, plymouth)
- **FR-014**: The Dockerfile MUST retain jq for JSON processing in Bash scripts
- **FR-015**: The Docker image filesystem (excluding model) MUST be under 3.5GB. Note: the original 1.5GB target did not account for the Linux kernel (~170MB), firmware (~389MB), and boot files (~174MB) which are required for a bootable OS image.

### Key Entities

- **Docker Base Image**: The Arch Linux-based container image that serves as the foundation for the Mohjave OS ISO. Contains all system packages needed at runtime.
- **Package Categories**: Packages are classified as REMOVE (no longer needed after Electron+cage pivot), ADD (new requirements), or KEEP (still needed at runtime).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Docker image filesystem (excluding LLM model) is under 3.5GB, down from the previous ~4GB+ package footprint. Note: kernel, firmware, and boot files account for ~730MB of the total.
- **SC-002**: All 12 packages explicitly marked for removal are absent from the built image (verified by pacman queries). xdg-utils remains as an expected transitive dependency of sddm.
- **SC-003**: cage compositor is present and executable in the built image
- **SC-004**: All 22 retained packages are present and at expected versions in the built image
- **SC-005**: The full ISO (with model + Electron + apps) targets under 4.5GB total size
- **SC-006**: The Dockerfile builds successfully without errors on a clean Docker build

## Assumptions

- Decision 7 (Electron on cage) is finalized and cage is the chosen compositor
- Electron is NOT installed via pacman in the Dockerfile — it is bundled with the mohjave-desktop app and added during ISO build, not in this Docker image
- nodejs and npm are not needed at runtime since Electron bundles its own Node.js
- The alpha release is live USB only, so no installer (calamares) is needed
- paru must be built from source because paru-bin has libalpm version mismatches on Arch's rolling release. Build tools (rustup, base-devel) are installed and removed in the same Docker layer.
- base-devel and rustup are temporarily installed during the Docker build for paru compilation and AUR package installs, then removed in the same layer so they do not persist in the final image
- This spec covers only the mowmo repo (Dockerfile changes). The mohjave repo ISO packaging changes are out of scope
- llama.cpp-bin (pre-compiled binary) is installed via paru from AUR, replacing the previous llama.cpp source build
