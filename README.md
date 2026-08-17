# Fenrir

A CachyOS-based live/installable ISO that boots straight into a fully
configured [Hyprland](https://hyprland.org/) + [Caelestia](https://github.com/caelestia-dots)
desktop, with no manual setup. Built for personal use and a small circle of
friends rather than general distribution.

Under the hood it's still CachyOS (kernel, package repos, keyring, hardware
detection) with a different desktop stack layered on top and its own
installer, [`fenrir-installer`](fenrir-installer/), replacing Calamares.

## What's different from a normal CachyOS spin

- **Hyprland + Caelestia baked in.** The live image ships the full Caelestia
  shell, dotfiles, and theme, symlinked into `/etc/skel` with relative paths
  so both the live user and any account `fenrir-installer` creates land in a
  working desktop immediately.
- **A themed, from-scratch installer.** `fenrir-installer` is a small
  GTK4/libadwaita app that reads Caelestia's live colour scheme and themes
  itself from it. It only asks what actually needs asking: locale, keyboard,
  which disk to erase, and a hostname/user/password. No bootloader or
  desktop chooser, since there's only ever one answer for either.
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

## Testing in QEMU

```bash
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 8G -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
  -drive file="$(command ls -t out/fenrir/*.iso | head -1)",media=cdrom,if=none,id=iso \
  -device virtio-scsi-pci,id=scsi \
  -device scsi-cd,drive=iso,bootindex=1 \
  -drive file=./fenrir-test.qcow2,if=none,id=disk \
  -device virtio-blk-pci,drive=disk,bootindex=2 \
  -vga virtio -display gtk
```

(`OVMF_VARS.fd` needs to be your own writable copy of
`/usr/share/edk2/x64/OVMF_VARS.4m.fd`, and `fenrir-test.qcow2` a disk image
created with `qemu-img create -f qcow2 fenrir-test.qcow2 20G`. Using a
combined `-bios OVMF.4m.fd` instead won't persist the bootloader's NVRAM
entry between boots.)

## Attribution

Fenrir is built on top of [CachyOS](https://cachyos.org/) and bundles
[Caelestia](https://github.com/caelestia-dots)'s dotfiles and shell. See
[THIRD_PARTY.md](THIRD_PARTY.md) for licensing details.
