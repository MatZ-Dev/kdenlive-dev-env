# kdenlive-dev-env

Arch Linux container for building, running and debugging **kdenlive master**, driven
from **Qt Creator running on the host**. Editing, searching and the IDE stay native;
cmake, ninja, gdb and clangd all execute inside the container.

---

## Why a container

kdenlive master tracks bleeding-edge KDE Frameworks and MLT. From `CMakeLists.txt`:

| Dependency | master requires | Ubuntu 24.04 (host) | Ubuntu 26.04 LTS | Arch (this image) |
|---|---|---|---|---|
| ECM / KF6 | ≥ 6.21.0 | 5.115.0 ❌ | 6.24.0 ✅ | 6.31.0 ✅ |
| Qt 6 | ≥ 6.10.0 | — | 6.10.2 ✅ | 6.12.0 ✅ |
| MLT 7 | ≥ 7.42.0 | — | 7.36.1 ❌ | 7.42.0 ✅ |
| KDDockWidgets-qt6 | ≥ 2.4.0 | — | 2.4.0 ✅ | 2.5.1 ✅ |

The host is a KF5-era system, so it cannot configure the project at all — a host kit
fails at `find_package(ECM 6.21.0)`.

**Why Arch and not Ubuntu 26.04:** only MLT falls short there, but `MLT_MIN_VERSION`
is set to the newest MLT in existence (kdenlive and MLT are co-developed), and an LTS
freezes versions for its lifetime. Ubuntu would mean building MLT from source now and
again at every floor bump. Arch gets everything from packages.

Trade-off: `archlinux:latest` + `pacman -Syu` is **not reproducible** — two builds a
month apart give different Qt/KF6 versions. Pin via `archive.archlinux.org` if you ever
need a stable bisect environment.

---

## Layout

```
kdenlive-dev/
├── docker/
│   ├── arch-env/Dockerfile       # build/debug env, IDE runs on the host
│   └── all-in-one-dev/Dockerfile # older: Qt Creator inside the container
├── .devcontainer/
│   └── devcontainer.json         # alternative to hand-configuring the device
├── docker-compose.yml            # manual shell only — Qt Creator ignores this
├── .env                          # local paths (SRC, BUILD, CCACHE, UID, GID)
├── Makefile
└── shell.sh                      # shell into the all-in-one image
```

Source checkout lives separately at `../kdenlive`.

---

## Prerequisites

- Docker (tested on 29.6.1) and Docker Compose, user in the `docker` group
- Qt Creator 20 with the **Docker** plugin (and **Development Container Support** for
  the devcontainer route) enabled under Help > About Plugins
- An X11 session (`XDG_SESSION_TYPE=x11`). Wayland is untested.

---

## Build the image

```bash
make build          # docker compose build  -> kdenlive-arch-env:latest
```

Result is ~3.07 GB. Contains cmake, ninja, gcc, g++, gdb, clangd, ccache,
dbus-daemon, and the full mlt + kdenlive dependency closure. No IDE.

---

## Usage A — manual shell

```bash
make shell          # xhost +local:docker, then docker compose run --rm
```

Lands in bash as `mz` (1000:1000), cwd = source tree, with ccache, X11 and PulseAudio
wired up. Inside:

```bash
cmake -S ../kdenlive -B <build> -G Ninja \
      -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_INSTALL_PREFIX=<build>/install \
      -DCMAKE_C_COMPILER=/usr/lib/ccache/bin/gcc \
      -DCMAKE_CXX_COMPILER=/usr/lib/ccache/bin/g++
ninja -C <build>
ninja -C <build> install

. <build>/prefix.sh
dbus-run-session kdenlive
```

---

## Usage B — host Qt Creator, Docker device

1. **Help > About Plugins > Device Support > Docker**, restart.
2. **Preferences > Devices > Docker** tab → Command: `/usr/bin/docker`
3. **Devices > Add > Docker Device > Start Wizard** → select `kdenlive-arch-env`.
4. Configure the device:

| Setting | Value |
|---|---|
| Run as outside user | on — keeps build output owned by `mz` |
| Enable flags needed for LLDB | on — adds `--cap-add=SYS_PTRACE --security-opt seccomp=unconfined`, needed by gdb |
| Mount Command Bridge | on |
| Network | `host` |
| Paths to mount | `/home/mz/work/projects/kde-dev/kdenlive`<br>`/home/mz/.cache/ccache-kdenlive`<br>`/run/user/1000/pulse` |
| Container environment | `CCACHE_DIR=/home/mz/.cache/ccache-kdenlive`<br>`XDG_RUNTIME_DIR=/run/user/1000`<br>`PULSE_SERVER=unix:/run/user/1000/pulse/native` |
| clangd | `/usr/bin/clangd` |

**Do not** add `/tmp/.X11-unix` — see gotcha 1.

5. **Auto-detect Kit Items** with *Search locations* = **Search in Selected
   Directories**, directories `/usr/bin;/usr/lib/ccache/bin`. Never "Search in PATH"
   — see gotcha 2.
6. In the kit, set compilers to `/usr/lib/ccache/bin/{gcc,g++}` (not the bare ones, or
   you lose ccache), debugger `/usr/bin/gdb`, cmake `/usr/bin/cmake`.
7. Open `../kdenlive/CMakeLists.txt` **by its host path** (not a `docker://` path, or
   searching runs in the container and is slow), select the Docker kit.
8. Set `CMAKE_INSTALL_PREFIX` to a writable path — see gotcha 6.
9. Start the session bus and add it to the run environment — see gotcha 3.

Debugging needs no source-path mapping: source and build are mounted at identical
absolute paths, so the paths gdb reports are valid on the host too.

---

## Usage C — devcontainer.json

`.devcontainer/devcontainer.json` encodes everything above as config, and adds a
`postStartCommand` that starts the session bus automatically — the one thing the
Docker device cannot do.

Qt Creator only looks for it in the **project** directory, and the project is the
upstream KDE checkout, so link it in when you want it:

```bash
ln -s ../../kdenlive-dev/.devcontainer ../kdenlive/.devcontainer
```

Then enable **Development Container Support** and reopen the project.

Unverified in this setup: whether the plugin honours `remoteUser` (if build output
comes out root-owned, suspect that), and whether `containerEnv` reaches run
configurations (if Run exits 1, re-add `DBUS_SESSION_BUS_ADDRESS` under
Projects > Run Settings > Environment).

---

## Gotchas

Each of these cost real time. Causes are confirmed, not guessed.

### 1. `Duplicate mount point: /tmp/.X11-unix`

Qt Creator does X11 forwarding itself — it adds `-e DISPLAY`, `-e XAUTHORITY`, an
xauth cookie mount and a read-only `/tmp/.X11-unix` mount. Listing `/tmp/.X11-unix` in
*Paths to mount* passes the same destination twice and the container fails to create.

**Fix:** leave X11 out of *Paths to mount*. Its read-only mount is fine — `connect()`
on a unix socket doesn't write to the filesystem.

### 2. Kit items show a red circle: "not executable"

On Arch, `/bin`, `/sbin` and `/usr/sbin` are all symlinks to `/usr/bin`, and the
container PATH contains four of them. Scanning PATH therefore registers **every tool
four times** (`/bin/gdb`, `/sbin/gdb`, `/usr/sbin/gdb`, `/usr/bin/gdb`), and the kit
can bind to an alias Qt Creator then rejects — even though the file is executable.

**Fix:** detect with *Search in Selected Directories* = `/usr/bin;/usr/lib/ccache/bin`,
or set kit items explicitly as `devcontainer.json` does.

### 3. kdenlive exits 1 immediately, with no error output

It needs a D-Bus session bus. Without one it exits 1 **silently**, which Qt Creator
reports as a bare `terminated with exit code 1`.

**Fix:** start a bus at a fixed address inside the container

```bash
docker exec <container> dbus-daemon --session --address=unix:path=/tmp/kdenlive-bus --fork
```

and add to Projects > Run Settings > Environment:

```
DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/kdenlive-bus
```

The bus dies whenever Qt Creator recreates the container (any device-settings change),
and Run breaks again the same silent way. `postStartCommand` in `devcontainer.json`
fixes this permanently.

### 4. Why not just `dbus-run-session kdenlive`?

Fine for Run, useless for Debug: it **forks** rather than exec'ing in place (measured:
the inner process got PID 8, not 1), so gdb would sit on the wrapper while kdenlive
runs as an unfollowed child. Qt Creator also can't debug a shell-script wrapper, since
gdb needs an ELF. Hence the fixed-address bus plus an env var, which works for both.

### 5. The host session bus cannot be shared

Mounting `/run/user/1000/bus` fails with:

```
An AppArmor policy prevents this sender from sending this message to this recipient
```

Not a permissions or passwd problem — Ubuntu's AppArmor policy. Don't waste time on it.

Related: the image **must** contain a real passwd entry for uid 1000. Without it
`getpwuid()` fails, `HOME` is unset, and both D-Bus auth and kdenlive's config
directory break.

### 6. `CMAKE_INSTALL_PREFIX` defaults to `/usr`

Qt Creator configures with the CMake default, which is not writable by uid 1000, so
`ninja install` fails. Worse, the generated `prefix.sh` then points `XDG_DATA_DIRS` at
`/usr/share`, where no kdenlive data exists — the container has kdenlive's
*dependencies*, not kdenlive itself.

**Fix:** set it to `<build>/install` in Build Settings > CMake. `dev-docs/build.md`
also warns that some Qt plugins (the MLT thumbnailer) still want system paths with a
user prefix — set `KDE_INSTALL_USE_QT_SYS_PATHS=OFF` to avoid needing root.

Startup survives without installing, but expect missing icons, menus and effect
metadata.

### 7. Qt Creator never sources `prefix.sh`

It doesn't run commands through a login shell, so the generated env script and any
`.bashrc` aliases are bypassed. Put what you need in the kit's build/run environment:

```
XDG_DATA_DIRS=<prefix>/share:/usr/local/share:/usr/share
XDG_CONFIG_DIRS=<prefix>/etc/xdg:/etc/xdg
```

`QT_PLUGIN_PATH` / `QML2_IMPORT_PATH` already point at the system Qt, so skip those.

### 8. `pacman -Scc --noconfirm` does nothing

Its first prompt — *"remove ALL files from cache?"* — defaults to `[y/N]`, and
`--noconfirm` takes defaults, so the answer is **no**. Measured: cache size unchanged
before and after; the all-in-one image carries **713 MB** of dead package cache
because of it.

Also, cleaning in a *separate* `RUN` cannot shrink the image — layers are additive and
a later delete only adds a whiteout.

**Fix:** `rm -rf /var/cache/pacman/pkg/*` chained onto the same `RUN` as each install.
`rm` rather than `-Scc` because it leaves the sync DB intact. Result: 44 KB retained.

### 9. Build dies mid-download on large packages

```
error: failed retrieving file 'gcc-...pkg.tar.zst' ... Operation too slow.
Less than 1 bytes/sec transferred the last 10 seconds
```

pacman's default low-speed limit aborts the whole transaction, and the Arch image's
mirrorlist has only two servers with no fallback. `DisableDownloadTimeout` is not
present in `/etc/pacman.conf` at all, so the Dockerfile inserts it into the first
`[options]` block before any pacman call.

Note this makes pacman wait indefinitely rather than fail, so a genuinely dead mirror
will hang instead of erroring. A wired connection fixed it here.

Because the cache clean is chained with `&&`, a failed build discards the layer and
**all** downloaded packages — a retry restarts from zero. BuildKit cache mounts
(`--mount=type=cache,target=/var/cache/pacman/pkg`) would make retries resume.

### 10. `HOME` is overridden

Qt Creator passes `-e HOME=/tmp/qtc_home/1000`, not `/home/mz`. The passwd entry still
resolves so D-Bus auth is fine, but kdenlive's config and cache land in a throwaway
path and don't persist across container restarts. Mount a real directory and set
`XDG_CONFIG_HOME` if that matters.

### 11. docker-compose.yml does not configure Qt Creator

The Docker device starts its **own** container from the image and ignores the compose
file entirely — mounts, env, user, caps. Compose only serves `make shell`. Keeping
both definitions 1:1 is what makes them agree.

Related: `CCACHE_DIR` must be mounted **1:1**. Qt Creator cannot remap a host directory
to a different path like `/ccache` inside the container.

### 12. Qt Creator rewrites its config on exit

Don't hand-edit `~/.config/QtProject/qtcreator/*.xml` while it's running — changes are
clobbered. Kits and their items are cross-referenced by generated UUIDs across
`profiles.xml`, `debuggers.xml`, `cmaketools.xml` and `toolchains.xml`, so the GUI is
the reliable route for kit changes.

---

## Known-good versions

Verified working: Docker 29.6.1, Qt Creator 20.0.0 (Qt 6.11.1), image
`kdenlive-arch-env:latest` with ECM 6.31.0 / Qt 6.12.0 / MLT 7.42.0 /
KDDockWidgets 2.5.1, building kdenlive master at `0d4b6e5ba5`.
