# Fenrir

A scrolling Linux desktop using [Hyprland](https://hyprland.org/) and a custom
fork of the [Caelestia](https://github.com/caelestia-dots) shell, themed from
install.

It's built on [CachyOS](https://cachyos.org/), with its own installer, settings
and update tooling on top.

<div align="center">

<br>

[![Download Fenrir ISO](https://img.shields.io/badge/Download-Fenrir%20ISO-897324?style=for-the-badge&logo=linux&logoColor=white)](https://sourceforge.net/projects/fenrir-os/)

**Early alpha.** Expect rough edges and the occasional bug, and back up anything
you care about before installing.

</div>

## What you get

**An already configured desktop on install.** The live session and every
installed account start in a themed Hyprland + Caelestia desktop: bar, launcher,
dashboard, notifications, lock screen and wallpaper are already done, so there's
no need to configure anything unless you want to.

**Less need to edit config files to customize.** Fenrir extends Caelestia's
settings app with pages for the things you'd otherwise hand-edit:

- **Personalise:** wallpaper and colour scheme, window widths and scrolling,
  gaps/rounding/blur/animations, desktop clock and visualiser, panels
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

**A sleek custom installer made just for Fenrir.** It's built from Caelestia's
components, so the design is coherent with the rest of the system.

**Sensible defaults.** Firewall on, driverless network printing, night light,
zram plus a swapfile, and out-of-memory protection that closes the app hogging
memory before the whole system stalls.

**A walkthrough on your first boot** in case you're new to scrolling desktops,
with the basics of getting around the row of windows and one-click extras:
gaming, Flatpak, printer drivers, media codecs, developer tools and graphics
driver detection.

Default apps: Zen Browser, foot terminal with fish, Thunar, VSCodium and Shelly
(a package manager GUI).

## Before you install

- **The installer erases the whole disk you pick.** In the future there will be
  an option for more advanced partitioning.
- **Turn off Secure Boot** in your BIOS settings first. Fenrir isn't signed for
  it yet.
- **There's no disk encryption option yet.**
- You need a 64-bit (x86-64) PC. UEFI is the tested path; legacy BIOS support is
  new and untested, so be aware.
- Plan on at least 4 GB of RAM (8 GB is recommended; the desktop idles at around
  1.5 GB) and 32 GB of disk.

### Making a USB stick

**On Linux**, use [Ventoy](https://www.ventoy.net/),
[Fedora Media Writer](https://github.com/FedoraQt/MediaWriter), or `dd` (this
erases `/dev/sdX`, so double-check the device):

```bash
sudo dd if=fenrir-linux-XXXXXX.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**On Windows**, I recommend [Rufus](https://rufus.ie/) or
[balenaEtcher](https://etcher.balena.io/).

### Known issues

- The Limine boot menu is hidden. To access your snapshots, spam ESC during
  bootup.
- Most testing happens in QEMU and on a couple of laptops, so hardware coverage
  is thin. I would greatly appreciate any bug reports about hardware
  incompatibility.

## What's next

- Optional full-disk encryption
- An advanced install mode: custom partitioning and installing alongside Windows
- A restore-points page in Settings, and backups of your home folder
- Exporting and importing your settings
- Better welcome screen
- Support for Secure Boot

## Building from source

You need an Arch-based system with the CachyOS repos enabled. CachyOS itself or
Fenrir both work.

```bash
sudo pacman -S --needed archiso devtools git squashfs-tools mkinitcpio-archiso grub fakeroot
git clone https://github.com/lawki2/Fenrir.git fenrir-iso
cd fenrir-iso
```

1. Build Fenrir's packages, plus the AUR ones it needs, into `local-repo/`. Run
   it as your normal user; it asks for `sudo` when it sets up a clean build
   chroot. The first run builds everything and takes a while. After that it only
   rebuilds packages whose sources changed.

   ```bash
   ./build-local-repo.sh
   ```

2. Build the ISO. It won't start if a package in `local-repo/` is older than its
   source, so run step 1 again after you change anything.

   ```bash
   sudo ./buildiso.sh -w
   ```

   `-w` deletes the work directory when it's done. The ISO ends up in
   `out/fenrir/`.

I'd test it in a VM before putting it on real hardware. For UEFI in QEMU, keep a
writable copy of the OVMF variables so boot entries survive between runs:

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd OVMF_VARS.fd
qemu-img create -f qcow2 fenrir-test.qcow2 40G
qemu-system-x86_64 -enable-kvm -cpu host -m 4G -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -drive file=fenrir-test.qcow2,if=virtio \
  -cdrom out/fenrir/fenrir-linux-XXXXXX.iso -boot d -vga virtio
```

Publishing packages to the `[fenrir]` repo (`publish-fenrir-repo.sh`) needs the
project's signing key, so that step is just me.

### Repository layout

| Path | What's in it |
|---|---|
| `fenrir-installer/` | The installer: QML UI in `qml/`, Python install backend in `lib/` |
| `fenrir-settings/` | Fenrir's system defaults as a package: Hyprland config, the update helper, pacman hooks, printing, memory protection |
| `fenrir-nexus-patches/` | Fenrir's changes to Caelestia's shell and settings app, copied over it at build time |
| `fenrir-splash/` | The Plymouth boot theme, and the splash that covers login until the lock screen is up |
| `fenrir-welcome/`, `fenrir-keyring/` | The welcome window's app entry; the repo signing key for installed systems |
| `archiso/` | The live image: package list, boot menus, live-only files |
| `tools/` | Build checks, the Caelestia update helper, image renderers |
| `build-local-repo.sh`, `buildiso.sh` | The two build steps above |

## Contributing

The most helpful thing right now is trying Fenrir and telling me what broke. Bug
reports, ideas and pull requests are all welcome.
[CONTRIBUTING.md](CONTRIBUTING.md) has what to put in a bug report and how to get
a change in.

## Credits and license

Fenrir is built on [CachyOS](https://cachyos.org/) and its
[live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), and bundles
[Caelestia](https://github.com/caelestia-dots)'s shell and dotfiles.
See [THIRD_PARTY.md](THIRD_PARTY.md) for the licenses of bundled components.
Fenrir's own code is licensed under [GPL-3.0](LICENSE).

Built with the help of AI tools, mainly [Claude](https://claude.com).
