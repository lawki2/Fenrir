# Fenrir

A Linux desktop that's finished when it boots. Fenrir installs
[Hyprland](https://hyprland.org/) and the [Caelestia](https://github.com/caelestia-dots)
shell already themed, configured and wired together, and puts everything you'd
normally change in a dotfile into a settings app instead.

It's built on [CachyOS](https://cachyos.org/) (Arch underneath), with its own
installer, settings and update tooling on top.

<div align="center">

<br>

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://sourceforge.net/projects/fenrir-os/)

**Early alpha.** Expect rough edges and the occasional bug, and back up anything
you care about before installing.

</div>

## What you get

**A working desktop from the first boot.** The live session and every installed
account start in a themed Hyprland + Caelestia desktop: bar, launcher, dashboard,
notifications, lock screen and wallpaper, all set up. There's no config file to
edit before it's usable.

**A settings app instead of dotfiles.** Fenrir extends Caelestia's settings app
with pages for the things you'd otherwise hand-edit:

- **Personalise:** wallpaper and colour scheme, gaps/rounding/blur/animations,
  desktop clock and visualiser, panels
- **Screen:** arrange monitors by dragging, resolution, refresh rate, scale and
  rotation (with a revert countdown), night light on a schedule
- **Connectivity and devices:** Wi-Fi/VPN, firewall rules, Bluetooth, audio, printers
- **Input:** mouse and touchpad, rebinding any shortcut by pressing the new keys,
  keyboard layouts and language
- **System:** power and sleep, updates, apps and notifications

**Updates you can undo.** Settings > Updates installs system and firmware updates
(it runs the same `pacman -Syu` you would in a terminal). Every update takes a
btrfs snapshot before and after it, so a bad one can be rolled back. Fenrir's own
packages, including its Hyprland defaults, come from a signed repository, so the
desktop gets fixes through normal updates instead of stale copies in your home
folder.

**An installer that looks like the desktop.** It's built from Caelestia's own
components and asks for your language, keyboard, the disk to use, and your name
and password. It installs by copying the live system, so no internet connection
is needed and what you tried is exactly what you get.

**Sensible defaults.** Firewall on, driverless network printing, night light,
zram plus a swapfile, and out-of-memory protection that closes the app hogging
memory (and tells you which) before the whole system stalls. The machine boots
straight to your locked desktop, so you type your password once.

**A welcome window on first login** with the basics of using a tiling desktop
and one-click extras: gaming (Steam and friends), Flatpak, printer drivers, media
codecs, developer tools and graphics driver detection.

Default apps: Zen Browser, foot terminal with fish, Thunar, VSCodium and Shelly
(a package manager GUI).

## Before you install

- **The installer erases the whole disk you pick.** Installing next to Windows
  or another OS isn't supported yet.
- **Turn off Secure Boot** in your firmware settings first. Fenrir isn't signed
  for it yet.
- **There's no disk encryption option yet.**
- You need a 64-bit (x86-64) PC. UEFI is the tested path; legacy BIOS support
  is new.
- Plan on at least 4 GB of RAM (8 GB is comfortable; the desktop idles around
  1.5 GB) and 32 GB of disk.

To make a USB stick, use [Ventoy](https://www.ventoy.net/),
[Fedora Media Writer](https://github.com/FedoraQt/MediaWriter), or `dd`
(this erases `/dev/sdX`, so double-check the device):

```bash
sudo dd if=fenrir-linux-XXXXXX.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### Known issues

- The Limine boot menu is currently hidden, which also hides the snapshot entries
  you'd boot to roll back. A fix is on the way.
- Most testing happens in QEMU and on a couple of laptops, so hardware coverage is
  thin. Reports from other machines are the most useful thing you can send.

## What's next

- Optional full-disk encryption
- An advanced install mode: custom partitioning and installing alongside Windows
- A restore-points page in Settings, and backups of your home folder
- Exporting and importing your settings
- A first-boot tutorial with visuals
- Secure Boot support

## Building from source

You need an Arch-based system with CachyOS's repositories enabled (CachyOS
itself, or Fenrir):

```bash
sudo pacman -S --needed archiso devtools git squashfs-tools mkinitcpio-archiso grub fakeroot
git clone https://github.com/lawki2/Fenrir.git fenrir-iso
cd fenrir-iso
```

1. Build Fenrir's own packages and the AUR ones it needs into `local-repo/`. Run
   it as your normal user; it asks for `sudo` to set up a clean build chroot.
   The first run builds everything and takes a while; later runs only rebuild
   packages whose inputs changed.

   ```bash
   ./build-local-repo.sh
   ```

2. Build the ISO. It refuses to start if any package in `local-repo/` is older
   than its source, so rerun step 1 after changing anything.

   ```bash
   sudo ./buildiso.sh -w
   ```

   `-w` removes the work directory afterwards. The ISO ends up in `out/fenrir/`.

Try it in a VM before real hardware. For UEFI in QEMU, keep a writable copy of
the OVMF variables so boot entries survive between runs:

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd OVMF_VARS.fd
qemu-img create -f qcow2 fenrir-test.qcow2 40G
qemu-system-x86_64 -enable-kvm -cpu host -m 4G -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -drive file=fenrir-test.qcow2,if=virtio \
  -cdrom out/fenrir/fenrir-linux-XXXXXX.iso -boot d -vga virtio
```

Publishing packages to the `[fenrir]` repository (`publish-fenrir-repo.sh`) needs
the project's signing key, so only the maintainer can do that step.

### Repository layout

| Path | What it is |
|---|---|
| `fenrir-installer/` | The installer: QML UI in `qml/`, Python install backend in `lib/` |
| `fenrir-settings/` | Fenrir's system defaults as a package: Hyprland config, the update helper and guard, pacman hooks, printing, memory protection |
| `fenrir-nexus-patches/` | Fenrir's pages and fixes, overlaid onto Caelestia's shell and settings app at build time |
| `fenrir-splash/` | The Plymouth boot theme and the splash that covers login until the lock screen is up |
| `fenrir-welcome/`, `fenrir-keyring/` | The welcome window's launcher entry; the repository signing key for installed systems |
| `archiso/` | The live image profile: package list, boot menus, live-only files |
| `tools/` | Package table and build checks, Caelestia update helper, image renderers |
| `build-local-repo.sh`, `buildiso.sh` | The two build steps above |

## Contributing

Trying Fenrir and reporting what broke is the most helpful thing right now, and
bug reports, ideas and pull requests are all welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to file a useful report and how to get
a change in.

## Credits and license

Fenrir is built on [CachyOS](https://cachyos.org/) and its
[live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), and bundles
[Caelestia](https://github.com/caelestia-dots)'s shell and dotfiles. Default
wallpaper by Maria Lupan on [Unsplash](https://unsplash.com/photos/0IFvTeguMJs).
See [THIRD_PARTY.md](THIRD_PARTY.md) for the licenses of bundled components.
Fenrir's own code is licensed under [GPL-3.0](LICENSE).

Built with the help of AI tools, mainly [Claude](https://claude.com).
