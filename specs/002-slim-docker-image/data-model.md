# Data Model: Slim Docker Image

**Date**: 2026-03-25
**Feature**: 002-slim-docker-image

## Entities

This feature has no application-level data model. The "entities" are Docker image package categories that determine what is installed in the Dockerfile.

### Package Categories

| Category | Action | Packages |
|----------|--------|----------|
| Hyprland Ecosystem | REMOVE | hyprland, xdg-desktop-portal-hyprland, xdg-utils |
| Tauri/WebKitGTK | REMOVE | webkit2gtk-4.1 |
| Build Tools | REMOVE | rustup, base-devel, nodejs, npm |
| Hyprland Tools | REMOVE | grim, slurp, dunst |
| Installer | REMOVE | calamares |
| Compositor | ADD | cage (official repos) |
| Core System | KEEP | base, linux, linux-firmware, grub, efibootmgr, networkmanager, openssh, git, sudo, vim |
| Audio | KEEP | pipewire, pipewire-pulse, pipewire-alsa, wireplumber |
| Graphics | KEEP | mesa, vulkan-tools |
| Fonts | KEEP | ttf-jetbrains-mono, noto-fonts |
| LLM Inference | KEEP (swap) | llama.cpp-bin (was llama.cpp source build) |
| System Services | KEEP | sddm, polkit, plymouth |
| AUR Support | KEEP | paru (built from source, build tools removed in same Docker layer) |
| Utilities | KEEP | jq |

### Build-only Dependencies

These are installed temporarily during Docker build in a single RUN layer, then removed so they do not persist in the final image:

| Package | Why Needed | Notes |
|---------|-----------|-------|
| base-devel | gcc, make, fakeroot, etc. for compiling paru from source | Removed via `pacman -Rns` in same layer |
| rustup | Rust toolchain for compiling paru | Removed via `pacman -Rns` in same layer |

Note: paru-bin (pre-compiled) was rejected because it links against libalpm.so.15 while current Arch ships a newer version. Rolling release binaries go stale quickly.

### Package Installation Flow

```
1. pacman -Syu (system update)
2. pacman -S (all official repo runtime packages)
3. Create build user
4. sudo pacman -S base-devel rustup (temporary, in single RUN layer)
5. rustup default stable
6. makepkg paru (source build, as build user)
7. paru -S llama.cpp-bin (as build user, via paru)
8. sudo pacman -Rns rustup base-devel (cleanup in same layer)
9. sudo pacman -Scc (clear package cache in same layer)
```
