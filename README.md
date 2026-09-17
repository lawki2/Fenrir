# Fenrir

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://sourceforge.net/projects/fenrir-os/)

A Linux desktop that's already set up when you boot it. Install it and you
get [Hyprland](https://hyprland.org/) +
[Caelestia](https://github.com/caelestia-dots), themed and configured, with
no dotfiles to edit before it's usable.

Built with [CachyOS](https://cachyos.org/) as a base, with a different
desktop stack on top.

**Early alpha.** It started as a personal project and still has rough edges,
missing polish and the occasional bug. The current build needs an internet
connection to install, and it's worth backing up anything you care about
first.

Bug reports, feedback and contributions are welcome, see
[Contributing](#contributing) below.

## What's different

- **Hyprland and Caelestia are already set up.** The live image ships the
  Caelestia shell, dotfiles and theme wired up. The live session and any
  account the installer creates both start in a working, themed desktop
  instead of a bare tiling WM you have to configure first.
- **The installer looks like the desktop.**
  [`fenrir-installer`](fenrir-installer/) is a small QML/Quickshell app. It
  reads Caelestia's colour scheme and themes itself from it, so setup and
  desktop match. It asks for locale, keyboard, which disk to erase, and a
  hostname, user and password, and nothing else. Everything it installs is
  prebuilt, so there's no AUR access or compiling during setup.
- **Settings are moving out of config files.** A real settings page is
  slowly taking over from hand-edited configs. A good chunk is done, the
  rest is being worked through.

## What's planned

Where it's going from here:

- **The rest of the settings page.**
- **An offline installer.**
- **A first-boot tutorial.**
- **A login screen that matches the desktop.**

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

Bug reports, feedback and pull requests are all welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how the project's laid out and how
to get a change reviewed. Just trying it and reporting what broke counts
too, no formal bug report needed.

## Attribution

Fenrir is built on top of [CachyOS](https://cachyos.org/) and bundles
[Caelestia](https://github.com/caelestia-dots)'s dotfiles and shell. See
[THIRD_PARTY.md](THIRD_PARTY.md) for licensing details on those. Fenrir's
own code is licensed under [GPL-3.0](LICENSE).

Built with the help of AI tools, mainly [Claude](https://claude.com).
