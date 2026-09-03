# Fenrir

A Linux desktop that's actually finished the moment it boots. Insert the USB,
install, and you land in a fully themed, fully configured
[Hyprland](https://hyprland.org/) + [Caelestia](https://github.com/caelestia-dots)
setup, with no dotfiles to hand-edit and no window manager config to piece
together before it's usable. Tiling done the way it should feel: fast,
coherent, and genuinely nice to look at, not just functional.

It started as a personal project and is still early, so expect rough edges
here and there — this isn't a polished commercial release with a support
line behind it. Bug reports, feedback, and contributions are welcome; see
[Contributing](#contributing) below.

Under the hood it's still [CachyOS](https://cachyos.org/) (same kernel, same
package repos, same hardware support) with a different desktop stack layered
on top and its own installer, [`fenrir-installer`](fenrir-installer/),
replacing Calamares.

<div align="center">

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://mega.nz/file/q34VGBjS#okXNEUtizyZKU98HJEBA72q0AGTueBOKOmlxgWf_MY8)

`fenrir-linux-260819.iso`, sha256 `8977886c5de19e4c956be827dbefe880a8dbf21695c5736521992ecd96a0110c`

**Early alpha.** This is an early build. Expect rough edges, missing polish,
and the occasional bug. Back up anything you care about before installing,
same as you would for any early-stage OS.

</div>

## What's different

- **Hyprland + Caelestia baked in.** The live image ships the full Caelestia
  shell, dotfiles, and theme already wired up, so both the live session and
  any account the installer creates land in a working, styled desktop
  immediately, not a bare tiling WM you're expected to configure yourself.
- **A themed installer built to match**, not a generic one bolted on.
  `fenrir-installer` is a small QML/Quickshell app that reads Caelestia's
  live colour scheme and themes itself from it in real time, right down to
  the same fonts, motion, and rounded-corner language as the desktop it's
  about to set up. It only asks what actually needs asking: locale,
  keyboard, which disk to erase, and a hostname/user/password. No
  bootloader or desktop-environment chooser, since there's only ever one
  answer for either here.
- **Limine**, silently, as the only bootloader.
- **AUR packages prebuilt, not built at install time.** Caelestia's AUR-only
  dependencies (`caelestia-cli`, `caelestia-shell`, `caelestia-meta`, and a
  few of their own deps) are built ahead of time into a local pacman repo via
  `build-local-repo.sh`, so neither the ISO build nor an actual install ever
  needs AUR access.

## What's planned

Fenrir's still early. Roughly where it's headed from here:

- **Snapshots and rollback**, wired right into the boot menu: the safety net
  that makes trusting a rolling-release distro for daily use feel
  reasonable.
- **A real settings app**: keybinds, window rules, look & feel, and display
  layout, all editable without ever opening a config file.
- **A fully offline installer**: no network required, since the live
  session you're already running has everything it needs.
- **A proper first-boot tutorial** for anyone new to tiling window
  managers. A lightweight version already ships in the installer; a
  fuller one is coming.
- **Less "under the hood" visible during setup**: a real progress indicator
  instead of a wall of install logs, a quieter boot, and a login screen
  that actually matches the desktop.

Further out: Fenrir hosting its own package repo.

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
to get a change reviewed. If you just want to try it and say what broke.

## Attribution

Fenrir is built on top of [CachyOS](https://cachyos.org/) and bundles
[Caelestia](https://github.com/caelestia-dots)'s dotfiles and shell. See
[THIRD_PARTY.md](THIRD_PARTY.md) for licensing details on those. Fenrir's
own code is licensed under [GPL-3.0](LICENSE).

Built with the help of AI tools, mainly [Claude](https://claude.com).
