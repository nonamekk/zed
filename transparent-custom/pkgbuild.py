#!/usr/bin/env python3
import re, sys

source, out, version, pkgrel = sys.argv[1:5]
text = open(source).read()

# The CPU the editor is built for: the Ryzen 9600X this package is made for. The package then runs on
# Zen 5 only (Zen 4 lacks some of its instructions), and the runner's CPU, an older EPYC or a Xeon, can't
# run it either. So nothing built for this CPU may run during the build: see the build line below.
cpu = "znver5"
triple = "x86_64-unknown-linux-gnu"

def sub(pattern, new, count=1):
    global text
    text, hits = re.subn(pattern, new, text, flags=re.M)
    if hits < count:
        raise SystemExit(f"Arch's PKGBUILD changed: no match for {pattern!r}")

sub(r"^pkgver=.*$", f"pkgver={version}")
# Above Arch's own release of this version (pkgrel 1), so pacman takes this release when the versions match.
sub(r"^pkgrel=.*$", f"pkgrel={pkgrel}")
sub(r'^_archive=.*$', "_archive=zed")
sub(r"^source=\(.*\)$", 'source=("zed.tar.gz")')
sub(r"^sha256sums=\(.*\)$", "sha256sums=(SKIP)")
# Two builds instead of Arch's one. build() runs the cli binary on the runner to write the shell
# completions, so cli stays generic x86-64. The editor gets the CPU flag, and only through `--target`:
# with it, cargo keeps RUSTFLAGS away from build scripts and proc macros, which run on the runner too.
# C code compiled by build scripts (tree-sitter grammars) stays generic: with the host and the target
# being the same triple, the cc crate can't tell its host compiles from its target ones.
sub(r"^(\s*)cargo build --release --frozen --package zed --package cli$",
    r"\1cargo build --release --frozen --package cli"
    "\n"
    rf'\1RUSTFLAGS="$RUSTFLAGS -C target-cpu={cpu}" cargo build --release --frozen --target {triple} --package zed')
# Arch's release profile as it is (thin LTO, one codegen unit, opt-level 3), without its full debug
# info: that only feeds the debug package, which this build doesn't make (options below).
sub(r"^(\s*)export CARGO_PROFILE_RELEASE_DEBUG=2$", r"\1export CARGO_PROFILE_RELEASE_DEBUG=0")
# With --target, cargo puts the editor under the triple.
sub(r"target/release/zed ", f"$CARGO_TARGET_DIR/{triple}/release/zed ")
# The launcher finds the editor before it does anything else, --completions included, and looks for it
# only next to itself, so it gets the editor's path. It only checks that the file is there; it never runs it.
sub(r" --completions ", f' --zed "$CARGO_TARGET_DIR/{triple}/release/zed" --completions ', 5)
sub(r"target/release/", "$CARGO_TARGET_DIR/release/", 8)
text += "\noptions=(!debug !lto)\n"
open(out, "w").write(text)
