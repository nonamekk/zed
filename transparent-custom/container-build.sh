#!/usr/bin/env bash
# Runs inside archlinux:base-devel: installs the PKGBUILD's dependencies, then makepkg as a plain
# user (makepkg refuses root). /pkg holds the PKGBUILD and zed.tar.gz, /out receives the package.
set -euo pipefail
pacman -Syu --noconfirm --needed git python >/dev/null
# shellcheck source=/dev/null
source /pkg/PKGBUILD
pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}" >/dev/null
useradd -m builder
chown -R builder /pkg /out /target
runuser -u builder -- env \
  BUILDDIR=/tmp/build PKGDEST=/out SRCDEST=/pkg PACKAGER="zed-transparent-custom (GitHub Actions)" \
  CARGO_TARGET_DIR=/target CARGO_BUILD_JOBS="$(nproc)" CARGO_INCREMENTAL=0 \
  CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=0 \
  bash -c 'cd /pkg && makepkg -f --nodeps --nocheck --skipchecksums'
