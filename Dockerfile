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
        # Node.js + npm (Electron desktop runtime)
        nodejs \
        npm \
        # Electron runtime deps
        gtk3 \
        nss \
        alsa-lib \
        at-spi2-core \
        libdrm \
        # Utilities
        jq \
        curl \
        # Build deps for llama.cpp (cleaned up after build)
        cmake \
        gcc \
        make && \
    pacman -Scc --noconfirm

# Build llama.cpp from source as a static binary.
# The AUR llama.cpp-bin package uses shared backend plugins which fail
# in containers and minimal environments. A static build bundles all
# CPU backends into the binary — no .so loading required.
ARG LLAMA_CPP_TAG=b8508
RUN git clone --depth 1 --branch ${LLAMA_CPP_TAG} \
        https://github.com/ggml-org/llama.cpp.git /tmp/llama.cpp && \
    cd /tmp/llama.cpp && \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_STATIC=ON \
        -DGGML_NATIVE=OFF \
        -DLLAMA_CURL=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=ON && \
    cmake --build build --target llama-server -j$(nproc) && \
    cp build/bin/llama-server /usr/sbin/llama-server && \
    chmod +x /usr/sbin/llama-server && \
    cd / && rm -rf /tmp/llama.cpp && \
    # Clean up build deps (keep gcc runtime — needed for libstdc++)
    pacman -Rns --noconfirm cmake make && \
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

# Install paru (for future AUR packages, without llama.cpp-bin)
USER builduser
WORKDIR /home/builduser
RUN sudo pacman -S --noconfirm base-devel rustup && \
    rustup default stable && \
    git clone https://aur.archlinux.org/paru.git && \
    cd paru && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf paru .cargo .rustup && \
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
