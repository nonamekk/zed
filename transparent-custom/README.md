# zed-transparent-custom

Builds of [Zed](https://github.com/zed-industries/zed) for Arch Linux with two theme keys for transparent themes. The branch `zed-transparent-custom` is a Zed release tag plus one commit: the patch and this build setup. GitHub Actions builds every new stable Zed release with the patch applied and publishes the Arch package as a release and in a pacman repository hosted on this repository's releases.

## The patch

| Theme key | What it colors | Unset |
|---|---|---|
| `minimap.background` | the minimap's background | the editor background at 70% opacity, as in upstream Zed |
| `editor.subheader.hover_background` | a multibuffer file header while hovered | `element.hover`, as in upstream Zed |

Stock themes set neither key, so they look the same as in upstream Zed. The same changes are proposed upstream one per branch: `minimap-background` and `subheader-hover-background`.

## How a build happens

1. Lurks for latest stable Zed release every hour, and starts a build if it does find the one that isn't build yet.
2. The `build` job cherry-picks this branch's own commits onto that release (via `transparent-custom/rebase.sh`). A commit that doesn't apply fails the run.
3. It turns Arch's PKGBUILD into one for this source (`transparent-custom/pkgbuild.py`: Arch's `release` profile with thin LTO and one codegen unit, no debug info, the editor built for Zen 5, `pkgrel=1.5`) and builds the package in an `archlinux:base-devel` container (`transparent-custom/container-build.sh`).
4. The `release` job publishes the package as release `zed-<version>-transparent.<id>`, with the applied commits in its notes, and replaces the package and database in the `pacman-repo` release, which is the pacman repository.

The branch on GitHub isn't moved by the build: the workflow token can't push history that changes workflow files, and every Zed release changes Zed's own.

## After a Zed release

Nothing is needed while the commits apply. When a run fails, or to move the branch itself, rebase it locally and push:

```sh
git fetch https://github.com/zed-industries/zed tag <new tag>
git rebase --onto <new tag> <old tag> zed-transparent-custom
git push --force-with-lease fork zed-transparent-custom
```

The push starts a build of the rebased branch.

## Built for Zen 5

The editor (`/usr/lib/zed/zed-editor`) is built with `-C target-cpu=znver5`, so the package runs on Zen 5 CPUs only; other CPUs stop it with "illegal instruction". The runner's CPU can't run it either, so `pkgbuild.py` keeps everything that runs during the build generic: the editor alone is built with `--target`, which keeps the flag away from build scripts and proc macros, and the `zeditor` launcher, which the PKGBUILD runs to write the shell completions, stays generic x86-64. C code built by build scripts stays generic as well. For other CPUs change `cpu` in `pkgbuild.py`, or use `x86-64-v3` (any CPU with AVX2).

`pkgrel` goes up whenever the build changes for the same Zed version (1.3 → 1.4 for the CPU flag, 1.5 for the `release` profile); with the same version and `pkgrel`, pacman keeps the installed package.

## Install

Add the repository to `/etc/pacman.conf`, above `[extra]`:

```ini
[zed-transparent]
SigLevel = Optional TrustAll
Server = https://github.com/nonamekk/zed/releases/download/pacman-repo
```

Then `sudo pacman -Syu zed`. pacman takes a package from the first repository that has it, so `zed` comes from this one while it's listed above `[extra]`, whatever Arch's version or `pkgrel`. The packages aren't signed (signing would need a key stored on GitHub); `SigLevel = Optional TrustAll` accepts them, so the trust is in this GitHub account. To go back to Arch's package, remove the block and run `sudo pacman -Syuu`.

A single release can also be installed directly: `sudo pacman -U <package URL>`.

## Setup on GitHub

- `zed-transparent-custom` is the repository's default branch (scheduled workflows only start from it).
- Actions are enabled for the repository (a fork starts with them off). Zed's own workflows are removed from this branch, so only this build runs; `rebase.sh` leaves commits that only change `.github/workflows` out of the build, since Zed's releases keep changing those files.
- GitHub turns scheduled workflows off after 60 days without activity in a public repository; a manual run turns them back on.
