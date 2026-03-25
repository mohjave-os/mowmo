# Tasks: Slim Docker Base Image

**Input**: Design documents from `/specs/002-slim-docker-image/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not explicitly requested. Test tasks omitted. Verification is via Docker build + pacman queries (see quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No project structure changes needed — this feature modifies only the existing Dockerfile.

- [x] T001 Review current Dockerfile at Dockerfile and document all packages currently installed for baseline comparison

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No foundational infrastructure needed. The Dockerfile is the only file being modified.

**Checkpoint**: Baseline documented — Dockerfile rewrite can begin.

---

## Phase 3: User Story 1 - Remove Obsolete Packages (Priority: P1)

**Goal**: Remove all packages no longer needed after the Electron + cage pivot: Hyprland ecosystem, Tauri/WebKitGTK, build tools, and Hyprland tools.

**Independent Test**: Build the Docker image and verify removed packages return "not found" via `pacman -Q`.

### Implementation for User Story 1

- [x] T002 [US1] Remove Hyprland ecosystem packages (hyprland, xdg-desktop-portal-hyprland, xdg-utils) from the pacman -S block in Dockerfile
- [x] T003 [US1] Remove Tauri/WebKitGTK package (webkit2gtk-4.1) from the pacman -S block in Dockerfile
- [x] T004 [US1] Remove build tool packages (rustup, nodejs, npm) from the pacman -S block in Dockerfile
- [x] T005 [US1] Remove Hyprland tool packages (grim, slurp, dunst) from the pacman -S block in Dockerfile
- [x] T006 [US1] Remove the `RUN rustup default stable` line from Dockerfile (rustup is no longer installed)

**Checkpoint**: All 13 obsolete packages removed from Dockerfile. Image should build without them.

---

## Phase 4: User Story 2 - Add cage Compositor (Priority: P1)

**Goal**: Add the cage Wayland compositor to the official pacman package list.

**Independent Test**: Build image and verify `which cage` returns `/usr/bin/cage`.

### Implementation for User Story 2

- [x] T007 [US2] Add cage to the pacman -S package list in Dockerfile (official extra repo, between compositor comment and audio section)

**Checkpoint**: cage compositor installed in image.

---

## Phase 5: User Story 3 - Remove calamares Installer (Priority: P2)

**Goal**: Remove calamares from the AUR install step. Alpha is live USB only.

**Independent Test**: Build image and verify `pacman -Q calamares` returns "not found".

### Implementation for User Story 3

- [x] T008 [US3] Remove calamares from the `paru -S` command in Dockerfile (keep only llama.cpp-related package)

**Checkpoint**: calamares and its Qt dependencies no longer pulled into the image.

---

## Phase 6: User Story 4 - Eliminate Build Tools from Final Image (Priority: P2)

**Goal**: Build paru from source with build tools (rustup, base-devel) installed and removed in the same Docker layer, so they do not persist in the final image. Note: paru-bin was rejected due to libalpm.so version mismatches on Arch's rolling release.

**Independent Test**: Build image and verify `which paru` returns a valid path and `pacman -Q rustup` returns "not found".

### Implementation for User Story 4

- [x] T009 [US4] Remove base-devel from the main pacman -S block in Dockerfile (moved to the single-layer build step)
- [x] T010 [US4] Install base-devel and rustup temporarily in the paru build RUN layer, then remove them with `pacman -Rns` after paru and llama.cpp-bin are installed
- [x] T011 [US4] Consolidate the paru source build, llama.cpp-bin install, and build tool removal into a single RUN layer in Dockerfile so Docker only stores the final filesystem state

**Checkpoint**: paru built from source and functional, rustup and base-devel removed in same layer, not present in final image.

---

## Phase 7: User Story 5 - Verify Retained Packages (Priority: P1)

**Goal**: Ensure all packages that must be retained are still in the Dockerfile and the AUR install step is updated.

**Independent Test**: Build image and run pacman queries against all retained packages.

### Implementation for User Story 5

- [x] T012 [US5] Switch llama.cpp to llama.cpp-bin in the paru -S command in Dockerfile (pre-compiled binary, no build tools needed)
- [x] T013 [US5] Verify all retained packages are present in the pacman -S block in Dockerfile: base, linux, linux-firmware, grub, efibootmgr, networkmanager, openssh, git, sudo, vim, sddm, pipewire, pipewire-pulse, pipewire-alsa, wireplumber, mesa, vulkan-tools, ttf-jetbrains-mono, noto-fonts, polkit, plymouth, jq
- [x] T014 [US5] Update Dockerfile comments to reflect the new architecture (Wayland compositor section, remove references to Tauri/Hyprland)

**Checkpoint**: All retained packages confirmed present, Dockerfile comments updated.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and validation across all changes.

- [x] T015 Clean up the build user section in Dockerfile — remove .cache cleanup lines that referenced rustup/cargo artifacts
- [x] T016 Run `docker build -t mowmo:latest .` and verify the image builds successfully
- [x] T017 Run `docker images mowmo:latest --format '{{.Size}}'` — image is 5.29GB virtual (3.0GB filesystem); 2.63GB is kernel+firmware+runtime, 135MB is AUR layer. See notes.
- [x] T018 Run `make test` to verify existing integration tests pass with the updated image — 6/6 tests pass
- [x] T019 Run quickstart.md validation commands to verify all removed packages are absent and all retained packages are present

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **User Story 1 (Phase 3)**: Depends on T001 baseline review
- **User Story 2 (Phase 4)**: Can run in parallel with US1 (different lines in Dockerfile)
- **User Story 3 (Phase 5)**: Can run in parallel with US1/US2 (different section of Dockerfile)
- **User Story 4 (Phase 6)**: Depends on US1 T004 (rustup removal) — modifies the same build section
- **User Story 5 (Phase 7)**: Depends on US1, US3, US4 (needs final package list to verify)
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (Remove Obsolete)**: No dependencies on other stories — can start first
- **US2 (Add cage)**: Independent — single line addition
- **US3 (Remove calamares)**: Independent — modifies paru -S line
- **US4 (Switch paru-bin)**: Depends on US1 (rustup removal shares the build section)
- **US5 (Verify Retained)**: Depends on US1, US3, US4 — verification pass after all changes

### Parallel Opportunities

Since all changes are in a single file (Dockerfile), true parallel execution is limited. However, the tasks are ordered so that non-overlapping sections can be edited sequentially without conflicts:

- T002-T006 (US1) modify the pacman -S block and rustup line
- T007 (US2) adds one line to the pacman -S block
- T008 (US3) modifies the paru -S line
- T009-T011 (US4) modify the pacman -S block and the paru build section
- T012-T014 (US5) modify the paru -S line and verify/update comments

**Recommended execution**: Sequential T001 → T002-T006 → T007 → T008 → T009-T011 → T012-T014 → T015-T019

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001 (baseline)
2. Complete T002-T006 (remove all obsolete packages)
3. Build and verify — image should already be significantly smaller
4. **STOP and VALIDATE**: Run quickstart.md removed-package checks

### Incremental Delivery

1. T001 → Baseline documented
2. T002-T006 → Obsolete packages removed (biggest impact)
3. T007 → cage added (new compositor available)
4. T008 → calamares removed (installer gone)
5. T009-T011 → paru-bin switch (build tools eliminated)
6. T012-T014 → llama.cpp-bin + verification
7. T015-T019 → Polish, build, test, validate

### Single Developer Strategy

All tasks are sequential for a single Dockerfile. Estimated scope: ~30 minutes of Dockerfile editing + Docker build time for verification.

---

## Notes

- All changes are in a single file: `Dockerfile`
- No new files created, no source code changes
- The primary risk is the Docker build failing due to package dependency changes
- If a build fails, check pacman dependency resolution — some removed packages may be dependencies of retained packages
- Commit after each user story phase completion
