FROM archlinux:latest

# T006: Full system update and install all Mohjave system packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base \
        base-devel \
        linux \
        linux-firmware \
        grub \
        efibootmgr \
        networkmanager \
        openssh \
        git \
        sudo \
        vim \
        hyprland \
        xdg-desktop-portal-hyprland \
        xdg-utils \
        sddm \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        wireplumber \
        mesa \
        vulkan-tools \
        ttf-jetbrains-mono \
        noto-fonts \
        llama-cpp \
        webkit2gtk-4.1 \
        rustup \
        nodejs \
        npm \
        grim \
        slurp \
        dunst \
        polkit \
        plymouth \
        calamares \
        jq && \
    pacman -Scc --noconfirm

# Configure locale to en_US.UTF-8
RUN sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# T007: Install paru (AUR helper) - requires non-root build user
RUN useradd -m -G wheel builduser && \
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builduser && \
    chmod 0440 /etc/sudoers.d/builduser

USER builduser
WORKDIR /home/builduser
RUN git clone https://aur.archlinux.org/paru.git && \
    cd paru && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf paru .cargo .cache

USER root
WORKDIR /root

# T008: Copy mowmo CLI into image
COPY mowmo/mowmo.sh /usr/local/bin/mowmo
RUN chmod +x /usr/local/bin/mowmo

# Copy integration tests into image for make test
COPY tests/integration/ /usr/local/share/mowmo/tests/integration/
RUN chmod +x /usr/local/share/mowmo/tests/integration/*.sh
