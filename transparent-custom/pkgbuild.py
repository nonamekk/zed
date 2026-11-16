#!/usr/bin/env python3
import re, sys

source, out, version, pkgrel = sys.argv[1:5]
text = open(source).read()

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
sub(r"cargo build --release ", "cargo build --profile release-fast ")
sub(r"target/release/", "$CARGO_TARGET_DIR/release-fast/", 5)
text += "\noptions=(!debug !lto)\n"
open(out, "w").write(text)
