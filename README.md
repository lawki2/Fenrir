# Fenrir

A Linux desktop that's actually finished the moment it boots. Insert the USB,
install, and you land in a fully themed, fully configured
[Hyprland](https://hyprland.org/) + [Caelestia](https://github.com/caelestia-dots)
setup, with no dotfiles to hand-edit and no window manager config to piece
together before it's usable. Tiling done the way it should feel: fast,
coherent, and genuinely nice to look at, not just functional.

It started as a personal project and is still early, so expect rough edges
here and there. Bug reports, feedback, and contributions are welcome; see
[Contributing](#contributing) below.

Under the hood it's still [CachyOS](https://cachyos.org/) (same kernel, same
package repos) with a different desktop stack layered on top.

<div align="center">

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://sourceforge.net/projects/fenrir-os/)

**Early alpha.** This is an early build. Expect rough edges, missing polish,
and the occasional bug. Back up anything you care about before installing,
same as you would for any early-stage OS.

</div>

## What's different

- **Hyprland and Caelestia, already set up.** The live image ships the whole
  Caelestia shell, dotfiles, and theme wired up, so the live session and any
  account the installer creates both land in a working, styled desktop rather
  than a bare tiling WM you're expected to configure first.
- **An installer that matches the desktop.**
  [`fenrir-installer`](fenrir-installer/) is a small QML/Quickshell app that
  reads Caelestia's live colour scheme and themes itself from it, down to the
  same fonts and motion as the desktop it's about to install. It asks only
  what needs asking — locale, keyboard, which disk to erase, and a
  hostname/user/password — and everything it installs is prebuilt, so there's
  no AUR access or compiling during setup.
- **Settings you can click instead of edit.** We're in the process of moving
  the settings that actually matter out of config files and into a real
  settings page. A good chunk is there already; the rest is being worked
  through.

## What's planned

Fenrir's still early. Roughly where it's headed from here:

- **Snapshots and rollback**, wired right into the boot menu: the safety net
  that makes trusting a rolling-release distro for daily use feel
  reasonable.
- **The rest of the settings app**: window rules and deeper look & feel
  controls are the main things still living in config files.
- **A fully offline installer**: no network required, since the live
  session you're already running has everything it needs.
- **A proper first-boot tutorial** for anyone new to tiling window
  managers, beyond the lightweight one in the installer today.
- **Less "under the hood" visible during setup**: a login screen that
  actually matches the desktop is the last obvious seam.


## Building

```bash
sudo pacman -S --needed archiso devtools git squashfs-tools mkinitcpio-archiso grub
git clone https://github.com/lawki2/Fenrir.git fenrir-iso
cd fenrir-iso
```

Build the local AUR package repo once (rerun only when those packages need
updating):

```bash
./build-local-repo.sh
```

Then build the ISO:

```bash
sudo ./buildiso.sh -p fenrir -v -w
```

```
Usage: buildiso.sh [options]
    -c                 Disable clean work dir
    -r                 Enable building in RAM on systems with more than 23GB RAM
    -w                 Remove build directory (not the ISO) after ISO file is built
    -p <profile>       Buildset or profile [default: fenrir]
    -v                 Verbose output to log file, show profile detail (-q)
    -h                 This help
```

The finished ISO ends up in `out/fenrir/`.

## Contributing

Bug reports, feedback, and pull requests are all welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md) for how the project's laid out and how
to get a change reviewed. Just trying it and reporting what broke counts
too, no formal bug report required.

## Attribution

Fenrir is built on top of [CachyOS](https://cachyos.org/) and bundles
[Caelestia](https://github.com/caelestia-dots)'s dotfiles and shell. See
[THIRD_PARTY.md](THIRD_PARTY.md) for licensing details on those. Fenrir's
own code is licensed under [GPL-3.0](LICENSE).

Built with the help of AI tools, mainly [Claude](https://claude.com).
