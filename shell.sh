#!/usr/bin/env bash
# Drop into the Kdenlive build container.
# Source and build dirs are mounted at their HOST paths so that
# compile_commands.json works with clangd / Qt Creator on the host.
set -euo pipefail

SRC=/home/mz/work/projects/kde-dev/kdenlive
BUILD=/home/mz/work/projects/kde-dev/kdenlive-dev/build

mkdir -p "$BUILD" "$HOME/.cache/ccache-kdenlive"
xhost +local:docker >/dev/null

exec docker run -it --rm \
  -e DISPLAY="$DISPLAY" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$SRC:$SRC" \
  -v "$BUILD:$BUILD" \
  -v "$HOME/.cache/ccache-kdenlive:/ccache" \
  -e CCACHE_DIR=/ccache \
  -v /run/user/1000/pulse:/run/user/1000/pulse \
  -e PULSE_SERVER=unix:/run/user/1000/pulse/native \
  --user "$(id -u):$(id -g)" \
  -w "$SRC" \
  kdenlive-dev bash
