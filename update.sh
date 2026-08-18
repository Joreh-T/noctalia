#!/usr/bin/env bash
# Update noctalia to latest upstream and rebuild for this machine (Ubuntu 24.04).
#
# The ubuntu-24.04 branch carries local compatibility patches (wireplumber 0.4,
# libwayland 1.22, vendored stb). This script rebases them onto upstream/main
# (noctalia-dev/noctalia), rebuilds with the isolated sdbus-c++ v2 prefix
# (~/noctalia-deps) and g++-14, installs to ~/.local/bin, and — only after a
# successful build — pushes the branch to the fork (origin, Joreh-T/noctalia)
# as backup.
#
# After it finishes, restart noctalia (or re-login) to run the new build.
set -euo pipefail
cd "$(dirname "$0")"

DEPS="$HOME/noctalia-deps"
BUILD=build-release

command -v g++-14 >/dev/null || { echo "missing g++-14 (apt install g++-14)" >&2; exit 1; }
[ -d "$DEPS/lib/pkgconfig" ] || { echo "missing $DEPS (sdbus-c++ v2 prefix)" >&2; exit 1; }

echo "==> Fetching upstream..."
git fetch upstream

if [ "$(git rev-parse upstream/main)" != "$(git merge-base HEAD upstream/main 2>/dev/null || echo none)" ]; then
    echo "==> Rebasing ubuntu-24.04 patches onto upstream/main..."
    git rebase upstream/main
else
    echo "==> Already up to date with upstream/main."
fi

echo "==> Configuring (fresh build dir)..."
rm -rf "$BUILD"
CC=gcc-14 CXX=g++-14 meson setup "$BUILD" \
    --buildtype=release \
    --prefix="$HOME/.local" \
    --pkg-config-path="$DEPS/lib/pkgconfig" \
    -Dcpp_link_args="-Wl,-rpath,$DEPS/lib"

echo "==> Compiling..."
meson compile -C "$BUILD"

echo "==> Installing to ~/.local/bin..."
meson install --no-rebuild -C "$BUILD"

echo "==> Pushing ubuntu-24.04 to fork (backup)..."
git push --force-with-lease origin ubuntu-24.04

echo "==> Done. Restart noctalia (or re-login) to run the new build."
