FROM archlinux:latest

# Full system update and install all Mohjave runtime packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base \
        linux \
        linux-firmware \
        grub \
        efibootmgr \
        networkmanager \
        openssh \
        git \
        sudo \
        vim \
        # Wayland compositor (cage: single-window kiosk compositor)
        cage \
        # Login manager
        sddm \
        # Audio
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        wireplumber \
        # Graphics
        mesa \
        vulkan-tools \
        # Fonts
        ttf-jetbrains-mono \
        noto-fonts \
        # System services
        polkit \
        plymouth \
        # Utilities
        jq && \
    pacman -Scc --noconfirm

# Configure locale to en_US.UTF-8
RUN sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create non-root build user for AUR package builds
RUN useradd -m -G wheel builduser && \
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builduser && \
    chmod 0440 /etc/sudoers.d/builduser

# Install paru from source and AUR packages, then remove build tools
# All in one layer so build dependencies don't bloat the final image
USER builduser
WORKDIR /home/builduser
RUN sudo pacman -S --noconfirm base-devel rustup && \
    rustup default stable && \
    git clone https://aur.archlinux.org/paru.git && \
    cd paru && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf paru .cargo .rustup && \
    paru -S --noconfirm llama.cpp-bin && \
    rm -rf /home/builduser/.cache && \
    sudo pacman -Rns --noconfirm rustup base-devel && \
    sudo pacman -Scc --noconfirm

USER root
WORKDIR /root

# Copy mowmo CLI into image
COPY mowmo/mowmo.sh /usr/local/bin/mowmo
RUN chmod +x /usr/local/bin/mowmo

# Copy integration tests into image for make test
COPY tests/integration/ /usr/local/share/mowmo/tests/integration/
RUN chmod +x /usr/local/share/mowmo/tests/integration/*.sh
