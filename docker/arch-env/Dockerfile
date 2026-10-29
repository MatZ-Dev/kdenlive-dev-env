FROM archlinux:latest

# Update packages and remove cache
RUN pacman -Syu --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*
# Install toolchain and remove cache
RUN pacman -S --noconfirm base-devel git cmake extra-cmake-modules ninja ccache expac libx11 clang gdb && \
    rm -rf /var/cache/pacman/pkg/*
# Install dependeces for mlt and kdenlive and remove cache
RUN pacman -S --noconfirm $(expac -S "%D" mlt) $(expac -S "%D" kdenlive) && \
    rm -rf /var/cache/pacman/pkg/*

RUN groupadd -g 1000 mz && \
    useradd -u 1000 -g 1000 -m -s /bin/bash mz
