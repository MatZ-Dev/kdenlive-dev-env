FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm base-devel git cmake extra-cmake-modules ninja \
        ccache expac libx11 clang && \
    pacman -S --noconfirm $(expac -S "%D" mlt) $(expac -S "%D" kdenlive) && \
    pacman -Scc --noconfirm

WORKDIR /src

# Give UID 1000 a real passwd entry + writable HOME.
# Without it: getpwuid() fails, HOME is unset, DBus auth and
# Kdenlive's config directory both break.
RUN groupadd -g 1000 mz && \
    useradd -u 1000 -g 1000 -m -s /bin/bash mz

# Convenience: auto-source the build env, and a shortcut to launch
# Kdenlive on a private session bus (the shared host bus is refused).
RUN printf '%s\n' \
  'B=/home/mz/work/projects/kde-dev/kdenlive-dev/build' \
  '[ -f "$B/prefix.sh" ] && . "$B/prefix.sh"' \
  'alias b="ninja -C $B -j32"' \
  'alias bi="ninja -C $B -j32 && ninja -C $B install"' \
  'alias run="dbus-run-session kdenlive"' \
  'alias qt-run="dbus-run-session qtcreator"' \
  >> /home/mz/.bashrc

# IDE + debugger. Appended as its own layer so the large dependency
# layer above stays cached. -Syu (not -Sy) to avoid an Arch partial upgrade.
RUN pacman -Syu --noconfirm qtcreator gdb && pacman -Scc --noconfirm
