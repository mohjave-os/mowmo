# Tasks: Dockerfile + Arch Base Image to Registry

**Input**: Design documents from `/specs/001-dockerfile-base-image/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/mowmo-cli.md

**Tests**: Integration tests are REQUIRED per constitution Art. VI.3 ("Every mowmo command has at least one integration test").

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, licensing, and basic structure

- [X] T001 Create directory structure: mowmo/, sdk/, tests/integration/, .github/workflows/
- [X] T002 [P] Create LICENSE with GPL v3.0 full text + No-Competing-OS addendum clause per constitution Art. VII
- [X] T003 [P] Create .dockerignore excluding .git/, specs/, .specify/, .github/, tests/, *.md (except mowmo/README.md)
- [X] T004 [P] Create README.md with project overview, usage, build instructions, and contribution guidelines per constitution Art. IX

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create Makefile with targets: build (docker build), test (run integration tests in container), push (tag + push to registry), clean (remove local images)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Build the Arch Linux Base Image (Priority: P1) MVP

**Goal**: Produce a Docker image from archlinux:latest containing all Mohjave system packages, paru for AUR support, locale configured to en_US.UTF-8, and jq for mowmo JSON output.

**Independent Test**: `docker build -t mowmo:latest .` succeeds, `docker run --rm mowmo:latest pacman -Q hyprland` returns a version, `docker run --rm mowmo:latest which llama-server` returns a path, `docker run --rm mowmo:latest paru --version` succeeds.

### Implementation for User Story 1

- [X] T006 [US1] Create Dockerfile FROM archlinux:latest with pacman -Syu and full system package list (base, base-devel, linux, linux-firmware, grub, efibootmgr, networkmanager, openssh, git, sudo, vim, hyprland, xdg-desktop-portal-hyprland, xdg-utils, sddm, pipewire, pipewire-pulse, pipewire-alsa, wireplumber, mesa, vulkan-tools, ttf-jetbrains-mono, noto-fonts, llama-cpp, webkit2gtk-4.1, rustup, nodejs, npm, grim, slurp, dunst, polkit, plymouth, calamares, jq) and locale configuration (en_US.UTF-8) in Dockerfile
- [X] T007 [US1] Add paru installation to Dockerfile: create builduser with passwordless sudo, git clone paru from AUR, makepkg -si --noconfirm, clean up build artifacts (.cargo, .cache, source dir), switch back to root per research.md R1
- [X] T008 [US1] Add COPY of mowmo/mowmo.sh into image at /usr/local/bin/mowmo with execute permissions, verify PATH includes /usr/local/bin in Dockerfile

**Checkpoint**: User Story 1 complete — image builds with all packages, paru available, locale set

---

## Phase 4: User Story 2 - Publish to Container Registry (Priority: P1)

**Goal**: Automate build and push of the Docker image to registry.core.mohjave.com via GitHub Actions with :latest and date-based :YYYY-MM-DD tags.

**Independent Test**: Push to main triggers the workflow, image appears at registry.core.mohjave.com/mowmo:latest and registry.core.mohjave.com/mowmo:YYYY-MM-DD.

### Implementation for User Story 2

- [X] T009 [US2] Create .github/workflows/build.yml: trigger on push to main, ubuntu-latest runner, steps: checkout (actions/checkout@v4), setup buildx (docker/setup-buildx-action@v3), login to registry.core.mohjave.com (docker/login-action@v3 with secrets.REGISTRY_HTPASSWD_USER and secrets.REGISTRY_HTPASSWD_PASS), generate tags (docker/metadata-action@v5 with type=raw,value=latest and type=raw,value={{date 'YYYY-MM-DD'}}), build and push (docker/build-push-action@v5 with GHA cache) per research.md R2
- [X] T010 [US2] Add test step to GitHub Actions workflow: after build, run make test inside the built image to verify packages and mowmo before push

**Checkpoint**: User Story 2 complete — CI builds, tests, and pushes image to registry on every main push

---

## Phase 5: User Story 3 - mowmo Package Manager (Priority: P2)

**Goal**: Implement the mowmo v1 Bash CLI with 6 commands (install, remove, search, update, list, info), structured JSON output by default, --human flag for plain text, and exit codes per constitution Art. III.3.

**Independent Test**: Inside a running container, `mowmo install firefox` installs Firefox and outputs valid JSON, `mowmo search editor` returns JSON array of results, `mowmo --human install vim` outputs [mowmo]-prefixed text.

### Implementation for User Story 3

- [X] T011 [US3] Create mowmo/mowmo.sh scaffold: shebang (#!/usr/bin/env bash), set -euo pipefail, global --human flag parsing, command dispatcher (case statement for install/remove/search/update/list/info), json_output() helper using jq, json_error() helper, exit code constants (0=success, 1=not found, 2=conflict, 3=permission, 4=network, 5=disk, 99=unknown), usage/help text in mowmo/mowmo.sh
- [X] T012 [US3] Implement install command in mowmo/mowmo.sh: try pacman -S --noconfirm first, if package not found try paru -S --noconfirm for AUR, capture installed version, output JSON per contracts/mowmo-cli.md install schema, map pacman exit codes to mowmo exit codes
- [X] T013 [US3] Implement remove command in mowmo/mowmo.sh: pacman -R --noconfirm, output JSON per contracts/mowmo-cli.md remove schema
- [X] T014 [US3] Implement search command in mowmo/mowmo.sh: pacman -Ss, parse output lines into JSON array with name/version/description/source fields per contracts/mowmo-cli.md search schema
- [X] T015 [US3] Implement update command in mowmo/mowmo.sh: capture package list before update (pacman -Q), run pacman -Syu --noconfirm, diff package versions, output JSON with updated count and packages array per contracts/mowmo-cli.md update schema
- [X] T016 [US3] Implement list command in mowmo/mowmo.sh: pacman -Q, parse into JSON array with name/version fields, include count per contracts/mowmo-cli.md list schema
- [X] T017 [US3] Implement info command in mowmo/mowmo.sh: pacman -Qi (installed) or pacman -Si (available), parse into JSON with name/version/description/url/installed/size/depends fields per contracts/mowmo-cli.md info schema
- [X] T018 [US3] Implement --human output mode in mowmo/mowmo.sh: when --human flag is set, output [mowmo]-prefixed plain text lines per constitution Art. III.4 instead of JSON for all commands
- [X] T019 [P] [US3] Create mowmo/README.md with usage documentation, all 6 commands with examples, JSON output schema reference, --human flag, and exit code table

### Integration Tests for User Story 3

- [X] T020 [US3] Create tests/integration/run-tests.sh: test runner that executes all test_*.sh scripts inside the Docker image, reports pass/fail summary, exits non-zero on any failure
- [X] T021 [P] [US3] Create tests/integration/test_install.sh: verify mowmo install vim outputs valid JSON with status=success and package=vim, verify vim is actually installed after
- [X] T022 [P] [US3] Create tests/integration/test_remove.sh: install then remove a package, verify JSON output and package is gone
- [X] T023 [P] [US3] Create tests/integration/test_search.sh: verify mowmo search vim outputs valid JSON with non-empty results array
- [X] T024 [P] [US3] Create tests/integration/test_update.sh: verify mowmo update outputs valid JSON with status=success
- [X] T025 [P] [US3] Create tests/integration/test_list.sh: verify mowmo list outputs valid JSON with count > 0 and non-empty packages array
- [X] T026 [P] [US3] Create tests/integration/test_info.sh: verify mowmo info vim outputs valid JSON with expected fields (name, version, description, installed)

**Checkpoint**: User Story 3 complete — all 6 mowmo commands work with JSON output, --human mode, correct exit codes, and all integration tests pass

---

## Phase 6: User Story 4 - MCP Driver Interface Specification (Priority: P3)

**Goal**: Create a public specification document at sdk/mcp-driver-spec.md that fully describes the MCP driver interface contract: tool registration, stdio transport, health check, graceful shutdown, and token ceiling.

**Independent Test**: Open sdk/mcp-driver-spec.md and verify it contains all 5 required sections with protocol details, message formats, and constraints.

### Implementation for User Story 4

- [X] T027 [P] [US4] Create sdk/mcp-driver-spec.md with all 5 required sections: (1) Tool Registration Protocol — driver writes registration JSON to stdout with tool name, description, parameters JSON Schema; (2) Stdio Transport Format — JSON lines on stdin/stdout, tool_call/tool_result message types; (3) Health Check Protocol — kernel sends health_check, driver responds health_ok within 5 seconds; (4) Graceful Shutdown — SIGTERM with 10 second grace period before SIGKILL; (5) Constraints — one process per namespace, max 10 tools per driver, 60s execution timeout, 4096 token ceiling, network access requires manifest declaration, systemd-nspawn sandbox per constitution Art. IV

**Checkpoint**: User Story 4 complete — MCP driver spec is comprehensive and self-contained

---

## Phase 7: User Story 5 - Ensure No Private Code (Priority: P2)

**Goal**: Verify the repository contains no MCP driver implementation code, no files from crates/drivers/, and no proprietary Mohjave components.

**Independent Test**: Search the entire repository for crates/drivers/ paths, driver implementation patterns, kernel source, or model files — none should be found.

### Implementation for User Story 5

- [X] T028 [US5] Audit repository contents against constitution Art. VIII boundaries: verify no files from crates/drivers/, no MCP driver implementations, no kernel/orchestrator/shell code, no model files, no auth secrets — document audit result in a comment or PR description

**Checkpoint**: User Story 5 complete — repository passes boundary audit

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Quality assurance, validation, and hardening across all stories

- [X] T029 Run shellcheck on mowmo/mowmo.sh and tests/integration/*.sh — fix all warnings to achieve zero-warning compliance per constitution Art. VI.1
- [X] T030 Run quickstart.md validation: execute the full build-verify-test-push flow from quickstart.md and confirm all steps succeed
- [X] T031 Verify all 7 acceptance criteria from Jira MOH-367 pass (AC-1 through AC-7)
- [X] T032 [P] Verify all 7 success criteria from spec.md pass (SC-001 through SC-007)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — creates the Docker image all other stories need
- **US2 (Phase 4)**: Depends on US1 (needs a buildable Dockerfile) and US3 (test step runs mowmo)
- **US3 (Phase 5)**: Can start after Foundational — mowmo.sh is developed locally, but needs US1 image for testing
- **US4 (Phase 6)**: Can start after Setup — documentation only, no code dependencies
- **US5 (Phase 7)**: Can start after all implementation stories — verification step
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundational only — MVP target
- **US2 (P1)**: US1 + US3 (CI workflow builds image and runs tests)
- **US3 (P2)**: Foundational (development), US1 (integration testing inside Docker)
- **US4 (P3)**: Setup only — fully independent documentation task
- **US5 (P2)**: All stories complete — audit/verification

### Within User Story 3 (mowmo CLI)

- T011 (scaffold) must complete before T012-T018 (commands)
- T012-T018 (commands) are sequential (same file), but T019 (README) is parallel
- T020 (test runner) before T021-T026 (individual tests)
- T021-T026 (individual tests) can run in parallel (different files)

### Parallel Opportunities

- T002, T003, T004 (Setup files) — all parallel, different files
- T027 (US4 MCP spec) — can start as soon as Setup is done, fully parallel with US1/US3
- T021-T026 (integration tests) — all parallel, different files
- T019 (mowmo README) — parallel with T018 (--human mode)

---

## Parallel Example: Setup Phase

```text
# Launch all setup file tasks together:
Task T002: "Create LICENSE with GPL v3.0 + No-Competing-OS in LICENSE"
Task T003: "Create .dockerignore"
Task T004: "Create README.md"
```

## Parallel Example: Integration Tests

```text
# Launch all integration test tasks together:
Task T021: "Create tests/integration/test_install.sh"
Task T022: "Create tests/integration/test_remove.sh"
Task T023: "Create tests/integration/test_search.sh"
Task T024: "Create tests/integration/test_update.sh"
Task T025: "Create tests/integration/test_list.sh"
Task T026: "Create tests/integration/test_info.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Makefile)
3. Complete Phase 3: User Story 1 (Dockerfile builds)
4. **STOP and VALIDATE**: `docker build .` succeeds, key packages present
5. This alone unblocks ISO build pipeline exploration

### Incremental Delivery

1. Setup + Foundational -> Foundation ready
2. US1 (Dockerfile) -> Test: image builds -> MVP!
3. US3 (mowmo CLI) -> Test: commands work in container
4. US2 (CI/registry) -> Test: push to main triggers build+push
5. US4 (MCP spec) -> Test: document review (can be done anytime)
6. US5 (audit) -> Test: boundary check
7. Polish -> Final validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (Dockerfile) then US2 (CI)
   - Developer B: US3 (mowmo CLI + tests)
   - Developer C: US4 (MCP driver spec)
3. US5 (audit) + Polish after all stories merge

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Constitution Art. VI.3 requires integration tests for every mowmo command
- Constitution Art. VI.1 requires shellcheck zero warnings
- Commit format: type(scope): description per constitution Art. VI.4
- Scopes: mowmo, sdk, docker, ci per constitution
