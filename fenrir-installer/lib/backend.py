"""Does the actual install: partitioning, pacstrap, and target configuration.

Runs as root (the whole app is launched through pkexec), so no further
privilege escalation happens here, just plain subprocess calls. Every step
streams its output through the given progress callback so the UI's progress
page (and the serial console, since stdout is already piped to it by the
launcher) can show what's happening.
"""

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

TARGET = Path("/mnt")
PACKAGE_LIST = Path("/etc/fenrir-packages.x86_64")
BTRFS_SUBVOLUMES = ("@", "@home", "@root", "@srv", "@cache", "@tmp", "@log")
BTRFS_MOUNTS = {
    "@": "/",
    "@home": "/home",
    "@root": "/root",
    "@srv": "/srv",
    "@cache": "/var/cache",
    "@tmp": "/var/tmp",
    "@log": "/var/log",
}
MOUNT_OPTIONS = "compress=zstd,noatime"


class InstallError(Exception):
    pass


@dataclass
class InstallPlan:
    disk: str
    esp_mib: int
    timezone: str
    locale: str
    keyboard: str
    hostname: str
    full_name: str
    username: str
    password: str


def _stream(cmd, progress, **kwargs):
    progress(f"+ {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kwargs
    )
    for line in proc.stdout:
        progress(line.rstrip())
    proc.wait()
    if proc.returncode != 0:
        raise InstallError(f"{cmd[0]} exited with status {proc.returncode}")


def _chroot(cmd, progress):
    _stream(["arch-chroot", str(TARGET), *cmd], progress)


def list_disks():
    out = subprocess.run(
        ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,TYPE,PATH"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    import json

    data = json.loads(out)
    return [
        {
            "path": d["path"],
            "size": int(d["size"]),
            "model": (d.get("model") or "").strip(),
        }
        for d in data["blockdevices"]
        # lsblk reports zram and loop devices as TYPE="disk" too; neither
        # is a real install target.
        if d["type"] == "disk" and not d["name"].startswith(("zram", "loop"))
    ]


def _partition_paths(disk):
    sep = "p" if disk[-1].isdigit() else ""
    return f"{disk}{sep}1", f"{disk}{sep}2"


def partition_and_mount(disk, esp_mib, progress):
    boot_part, root_part = _partition_paths(disk)

    # A previous failed attempt can leave the target mounted, which makes
    # wipefs/sgdisk fail with "device busy" on retry. Clear that first;
    # it's expected to fail harmlessly when there's nothing mounted.
    progress("Clearing any leftover mounts from a previous attempt")
    subprocess.run(
        ["umount", "-R", str(TARGET)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )

    progress(f"Wiping {disk}")
    _stream(["wipefs", "-a", disk], progress)
    _stream(["sgdisk", "--zap-all", disk], progress)
    _stream(
        ["sgdisk", "-n", f"1:0:+{esp_mib}M", "-t", "1:ef00", "-c", "1:FENRIR_BOOT", disk],
        progress,
    )
    _stream(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:FENRIR_ROOT", disk], progress)
    _stream(["partprobe", disk], progress)

    progress("Formatting partitions")
    _stream(["mkfs.fat", "-F32", "-n", "FENRIR_BOOT", boot_part], progress)
    _stream(["mkfs.btrfs", "-f", "-L", "FENRIR_ROOT", root_part], progress)

    progress("Creating btrfs subvolumes")
    _stream(["mount", root_part, str(TARGET)], progress)
    for subvol in BTRFS_SUBVOLUMES:
        _stream(["btrfs", "subvolume", "create", str(TARGET / subvol)], progress)
    _stream(["umount", str(TARGET)], progress)

    progress("Mounting target filesystems")
    _stream(
        ["mount", "-o", f"subvol=@,{MOUNT_OPTIONS}", root_part, str(TARGET)], progress
    )
    for subvol, mountpoint in BTRFS_MOUNTS.items():
        if subvol == "@":
            continue
        target_path = TARGET / mountpoint.lstrip("/")
        target_path.mkdir(parents=True, exist_ok=True)
        _stream(
            ["mount", "-o", f"subvol={subvol},{MOUNT_OPTIONS}", root_part, str(target_path)],
            progress,
        )
    boot_path = TARGET / "boot"
    boot_path.mkdir(parents=True, exist_ok=True)
    _stream(["mount", boot_part, str(boot_path)], progress)


def read_package_list():
    if not PACKAGE_LIST.exists():
        raise InstallError(f"{PACKAGE_LIST} is missing from the live image")
    packages = []
    for line in PACKAGE_LIST.read_text().splitlines():
        name = line.split("#", 1)[0].strip()
        if name:
            packages.append(name)
    return packages


def pacstrap_target(progress):
    packages = read_package_list()
    _stream(["pacstrap", "-K", str(TARGET), *packages], progress)


def copy_skel(progress):
    # /etc/skel's Caelestia symlinks are an airootfs customization baked
    # only into the live squashfs, not something any package installs.
    # pacstrap alone leaves the target with the bare, near-empty /etc/skel
    # the base packages ship, so useradd -m later would create a user with
    # no Hyprland/Caelestia config at all. Copy the live session's own
    # already-configured /etc/skel onto the target to fix that.
    progress("Copying Caelestia configuration into /etc/skel")
    target_skel = TARGET / "etc/skel"
    target_skel.mkdir(parents=True, exist_ok=True)
    _stream(["cp", "-a", "/etc/skel/.", f"{target_skel}/"], progress)


def genfstab_target(progress):
    progress("Writing fstab")
    result = subprocess.run(
        ["genfstab", "-U", str(TARGET)], check=True, capture_output=True, text=True
    )
    (TARGET / "etc/fstab").write_text(result.stdout)


def configure_locale(timezone, locale, progress):
    progress(f"Setting timezone to {timezone}")
    _stream(
        ["ln", "-sf", f"/usr/share/zoneinfo/{timezone}", str(TARGET / "etc/localtime")],
        progress,
    )
    _chroot(["hwclock", "--systohc"], progress)

    progress(f"Generating locale {locale}")
    locale_gen = TARGET / "etc/locale.gen"
    with locale_gen.open("a") as f:
        f.write(f"{locale} UTF-8\n")
    _chroot(["locale-gen"], progress)
    (TARGET / "etc/locale.conf").write_text(f"LANG={locale}\n")


def configure_keyboard(layout, progress):
    progress(f"Setting keyboard layout to {layout}")
    (TARGET / "etc/vconsole.conf").write_text(f"KEYMAP={layout}\n")
    xorg_dir = TARGET / "etc/X11/xorg.conf.d"
    xorg_dir.mkdir(parents=True, exist_ok=True)
    (xorg_dir / "00-keyboard.conf").write_text(
        'Section "InputClass"\n'
        '    Identifier "system-keyboard"\n'
        '    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{layout}"\n'
        "EndSection\n"
    )


def configure_hostname(hostname, progress):
    progress(f"Setting hostname to {hostname}")
    (TARGET / "etc/hostname").write_text(f"{hostname}\n")
    (TARGET / "etc/hosts").write_text(
        "127.0.0.1\tlocalhost\n"
        "::1\t\tlocalhost\n"
        f"127.0.1.1\t{hostname}\n"
    )


def create_user(username, full_name, password, progress):
    progress(f"Creating user {username}")
    _chroot(
        ["useradd", "-m", "-G", "wheel", "-s", "/usr/bin/fish", "-c", full_name, username],
        progress,
    )
    for account in (username, "root"):
        proc = subprocess.run(
            ["arch-chroot", str(TARGET), "chpasswd"],
            input=f"{account}:{password}\n",
            text=True,
        )
        if proc.returncode != 0:
            raise InstallError(f"Failed to set password for {account}")


def configure_kernel_cmdline(root_part, progress):
    # limine-entry-tool falls back to reading /proc/cmdline for kernel
    # parameters when none are configured. Since arch-chroot always
    # bind-mounts /proc from the host, that's the *live ISO's* own boot
    # parameters in our case, not anything valid for the installed system,
    # and limine-entry-tool's own docs warn against exactly this case. It
    # also checks /etc/kernel/cmdline first, so writing the real value
    # there directly avoids that ever coming up.
    progress("Writing kernel command line")
    uuid = subprocess.run(
        ["blkid", "-s", "UUID", "-o", "value", root_part],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    kernel_dir = TARGET / "etc/kernel"
    kernel_dir.mkdir(parents=True, exist_ok=True)
    (kernel_dir / "cmdline").write_text(f"rw root=UUID={uuid} rootflags=subvol=@\n")


def finalize_bootloader(progress):
    # Registers the initial NVRAM boot entry for this fresh install.
    progress("Installing Limine")
    _chroot(["limine-install"], progress)
    # limine-update is the exact sequence limine-mkinitcpio-hook's own
    # tooling uses to regenerate everything: limine-install
    # --no-efi-register (skip re-touching NVRAM, already done above) then
    # limine-mkinitcpio, which is what actually writes each installed
    # kernel's real boot entry into limine.conf (and keeps the EFI
    # fallback path in sync via its own defaults) and has to run last, or
    # a later limine-install call can clobber limine.conf back down to
    # just its own generic placeholder entry.
    progress("Generating initramfs and Limine boot entries")
    _chroot(["limine-update"], progress)


ENABLED_SERVICES = ("NetworkManager", "systemd-timesyncd", "bluetooth", "fstrim.timer", "sddm", "ufw")


def enable_services(progress):
    for service in ENABLED_SERVICES:
        progress(f"Enabling {service}")
        _chroot(["systemctl", "enable", service], progress)


def configure_firewall(progress):
    # ufw ships with ENABLED=no until someone runs `ufw enable` - flip that
    # directly rather than running `ufw enable` inside the chroot, since
    # that also tries to apply the ruleset through netfilter immediately,
    # which is chroot state best left to the installed system's own first
    # real boot (where ufw.service, enabled above, applies it). Package
    # defaults otherwise (deny incoming, allow outgoing, deny forward, in
    # /etc/default/ufw) are left untouched - that's the standard policy.
    progress("Enabling firewall")
    (TARGET / "etc/ufw/ufw.conf").write_text(
        "# /etc/ufw/ufw.conf\n"
        "#\n"
        "\n"
        "# Set to yes to start on boot. If setting this remotely, be sure to add a rule\n"
        "# to allow your remote connection before starting ufw. Eg: 'ufw allow 22/tcp'\n"
        "ENABLED=yes\n"
        "\n"
        "# Please use the 'ufw' command to set the loglevel. Eg: 'ufw logging medium'.\n"
        "# See 'man ufw' for details.\n"
        "LOGLEVEL=low\n"
    )


def unmount_target(progress):
    progress("Unmounting target")
    # A process started during one of the arch-chroot calls above (notably
    # gpg-agent, from pacstrap's keyring setup) can outlive that invocation
    # and keep the target busy even though the install itself is done. Kill
    # anything still using it, then fall back to a lazy unmount if
    # something is still holding on regardless.
    subprocess.run(
        ["fuser", "-km", str(TARGET)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(1)
    result = subprocess.run(["umount", "-R", str(TARGET)])
    if result.returncode != 0:
        progress("Target still busy, forcing a lazy unmount")
        _stream(["umount", "-Rl", str(TARGET)], progress)


def run_install(plan: InstallPlan, progress):
    partition_and_mount(plan.disk, plan.esp_mib, progress)
    progress("Installing packages (this takes a while)")
    pacstrap_target(progress)
    copy_skel(progress)
    genfstab_target(progress)
    configure_locale(plan.timezone, plan.locale, progress)
    configure_keyboard(plan.keyboard, progress)
    configure_hostname(plan.hostname, progress)
    create_user(plan.username, plan.full_name, plan.password, progress)
    _, root_part = _partition_paths(plan.disk)
    configure_kernel_cmdline(root_part, progress)
    finalize_bootloader(progress)
    enable_services(progress)
    configure_firewall(progress)
    unmount_target(progress)
    progress("Install complete")
