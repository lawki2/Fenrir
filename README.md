# Fenrir

A Linux desktop that's actually finished the moment it boots. Insert the USB,
install, and you land in a fully themed, fully configured
[Hyprland](https://hyprland.org/) + [Caelestia](https://github.com/caelestia-dots)
setup — no dotfiles to hand-edit, no window manager config to piece together
before it's usable. Tiling done the way it should feel: fast, coherent, and
genuinely nice to look at, not just functional.

It's a personal project, built for myself and a small circle of friends
rather than general distribution — so expect rough edges here and there, not
a polished commercial release with a support line behind it.

Under the hood it's still [CachyOS](https://cachyos.org/) — same kernel,
same package repos, same hardware support — with a different desktop stack
layered on top and its own installer, [`fenrir-installer`](fenrir-installer/),
replacing Calamares.

<div align="center">

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://mega.nz/file/q34VGBjS#okXNEUtizyZKU98HJEBA72q0AGTueBOKOmlxgWf_MY8)

`fenrir-linux-260819.iso` — `sha256: 8977886c5de19e4c956be827dbefe880a8dbf21695c5736521992ecd96a0110c`

**Early alpha.** This is an early build. Expect rough edges, missing polish, and the occasional bug —
back up anything you care about before installing, same as you would for
any early-stage OS.

</div>

## What's different

- **Hyprland + Caelestia baked in.** The live image ships the full Caelestia
  shell, dotfiles, and theme already wired up, so both the live session and
  any account the installer creates land in a working, styled desktop
  immediately — not a bare tiling WM you're expected to configure yourself.
- **A themed installer built to match**, not a generic one bolted on.
  `fenrir-installer` is a small QML/Quickshell app that reads Caelestia's
  live colour scheme and themes itself from it in real time, right down to
  the same fonts, motion, and rounded-corner language as the desktop it's
  about to set up. It only asks what actually needs asking: locale,
  keyboard, which disk to erase, and a hostname/user/password — no
  bootloader or desktop-environment chooser, since there's only ever one
  answer for either here.
- **Limine**, silently, as the only bootloader.
- **AUR packages prebuilt, not built at install time.** Caelestia's AUR-only
  dependencies (`caelestia-cli`, `caelestia-shell`, `caelestia-meta`, and a
  few of their own deps) are built ahead of time into a local pacman repo via
  `build-local-repo.sh`, so neither the ISO build nor an actual install ever
  needs AUR access.

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

## Attribution

Fenrir is built on top of [CachyOS](https://cachyos.org/) and bundles
[Caelestia](https://github.com/caelestia-dots)'s dotfiles and shell. See
[THIRD_PARTY.md](THIRD_PARTY.md) for licensing details.

Built with the help of AI tools, mainly [Claude](https://claude.com).
