#!/usr/bin/env bash
# Runs inside archlinux:base-devel: the patch's own tests, on the source the build job builds (this
# branch's commits applied to the Zed release). /src holds that source, /pkg/PKGBUILD.arch is Arch's
# PKGBUILD, read only for its dependencies. A plain debug build for the runner's CPU, no znver5.
set -euo pipefail
pacman -Syu --noconfirm --needed git python >/dev/null
# shellcheck source=/dev/null
source /pkg/PKGBUILD.arch
pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}" >/dev/null
git config --global --add safe.directory '*'

# Every test the patch adds. libtest runs the tests whose names contain one of these, and a test that
# is renamed or removed would just not run, so each one has to show up as passed in the log below.
tests=(
  test_minimap_background_comes_from_theme
  explicit_minimap_background_takes_precedence_over_editor_background
  minimap_background_falls_back_to_translucent_editor_background
  minimap_background_is_absent_when_editor_background_is_missing
  explicit_subheader_hover_background_takes_precedence_over_element_hover
  subheader_hover_background_falls_back_to_element_hover
  subheader_hover_background_is_absent_when_element_hover_is_missing
)

cd /src
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1 ZSTD_SYS_USE_PKG_CONFIG=1
export PROTOC=/usr/bin/protoc PROTOC_INCLUDE=/usr/include
export CARGO_TARGET_DIR=/target CARGO_INCREMENTAL=0 CARGO_PROFILE_DEV_DEBUG=0 CARGO_BUILD_JOBS="$(nproc)"
cargo test --locked --lib --package theme_settings --package editor -- "${tests[@]}" 2>&1 | tee /tmp/test.log

failed=0
for t in "${tests[@]}"; do
  if ! grep -qE "^test (.*::)?$t \.\.\. ok\$" /tmp/test.log; then
    echo "::error::$t didn't run or didn't pass"
    failed=1
  fi
done
exit "$failed"
