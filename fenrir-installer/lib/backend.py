"""Does the actual install: partitioning, pacstrap, target configuration.
Runs as root already (launched via pkexec) — no escalation happens here.
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
    # stdbuf forces line buffering (piped output is block-buffered
    # otherwise, so pacstrap's progress arrives in one late burst);
    # nice/ionice keep this from starving the compositor thread.
    proc = subprocess.Popen(
        ["nice", "-n", "10", "ionice", "-c2", "-n7", "stdbuf", "-oL", "-eL", *cmd],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        **kwargs,
    )
    for line in proc.stdout:
        progress(line.rstrip())
    proc.wait()
    if proc.returncode != 0:
        raise InstallError(f"{cmd[0]} exited with status {proc.returncode}")


def _chroot(cmd, progress):
    # Strip LD_PRELOAD (set by _stream's stdbuf wrapper) before it leaks
    # into the chroot via arch-chroot's inherited environment.
    _stream(["arch-chroot", str(TARGET), "env", "-u", "LD_PRELOAD", *cmd], progress)


def _boot_medium_disk():
    # Resolves the live boot medium to its parent disk so list_disks()
    # can exclude it — wiping the running installer's own USB is unrecoverable.
    try:
        source = subprocess.run(
            ["findmnt", "-no", "SOURCE", "/run/archiso/bootmnt"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        parent = subprocess.run(
            ["lsblk", "-no", "PKNAME", source],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        # Whole-disk media (e.g. optical, no partition table) have no parent.
        return parent or source.removeprefix("/dev/")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def list_disks():
    out = subprocess.run(
        ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,TYPE,PATH"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    import json

    data = json.loads(out)
    boot_disk = _boot_medium_disk()
    return [
        {
            "path": d["path"],
            "size": int(d["size"]),
            "model": (d.get("model") or "").strip(),
        }
        for d in data["blockdevices"]
        # Exclude zram/loop pseudo-disks and the live boot medium itself.
        if d["type"] == "disk" and not d["name"].startswith(("zram", "loop")) and d["name"] != boot_disk
    ]


def _partition_paths(disk):
    sep = "p" if disk[-1].isdigit() else ""
    return f"{disk}{sep}1", f"{disk}{sep}2"


def partition_and_mount(disk, esp_mib, progress):
    boot_part, root_part = _partition_paths(disk)

    # Clear any mount left by a failed previous attempt; harmless if none exists.
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
    # partprobe can return before udev finishes creating the new device
    # nodes; wait for udev before mkfs races it.
    _stream(["udevadm", "settle"], progress)

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


# Filled in once the dedicated Fenrir package-signing key exists (see
# archiso/airootfs/etc/pacman.d/fenrir-signing-key.asc and secrets/ in the
# repo root) - re-derive via:
#   GNUPGHOME=secrets/gnupg gpg --show-keys --with-colons \
#       archiso/airootfs/etc/pacman.d/fenrir-signing-key.asc | awk -F: '/^fpr/{print $10; exit}'
FENRIR_REPO_KEY_FPR = "BE0B53BD597DF2CDB8437E869C17423CED27E4BE"


def configure_fenrir_repo(progress):
    # No key generated yet - a build made before then should ship with no
    # [fenrir] repo configured, not a hard install failure the moment
    # pacman-key is asked to trust a fingerprint that doesn't exist yet.
    if FENRIR_REPO_KEY_FPR is None:
        progress("Skipping Fenrir package repo — no signing key configured yet")
        return

    progress("Configuring the Fenrir package repository")

    live_mirrorlist = Path("/etc/pacman.d/fenrir-mirrorlist")
    live_key = Path("/etc/pacman.d/fenrir-signing-key.asc")
    for f in (live_mirrorlist, live_key):
        if not f.exists():
            raise InstallError(f"{f} is missing from the live image")

    pacman_d = TARGET / "etc/pacman.d"
    pacman_d.mkdir(parents=True, exist_ok=True)
    (pacman_d / "fenrir-mirrorlist").write_text(live_mirrorlist.read_text())
    (pacman_d / "fenrir-signing-key.asc").write_text(live_key.read_text())

    # Anchored on [core], not [cachyos] - [core] is guaranteed present in
    # pacman's own default template pacstrap just laid down, whereas
    # [cachyos] only exists here because CachyOS's own keyring/hooks
    # package injected it during this same pacstrap transaction.
    pacman_conf = TARGET / "etc/pacman.conf"
    lines = pacman_conf.read_text().splitlines()
    if not any(line.strip() == "[fenrir]" for line in lines):
        anchor = next(i for i, line in enumerate(lines) if line.strip() == "[core]")
        lines[anchor:anchor] = [
            "[fenrir]",
            "SigLevel = Required",
            "Include = /etc/pacman.d/fenrir-mirrorlist",
            "",
        ]
        pacman_conf.write_text("\n".join(lines) + "\n")

    # pacstrap -K above already initialized a fresh keyring at
    # etc/pacman.d/gnupg for this target, so pacman-key has something to
    # add to.
    _chroot(["pacman-key", "--add", "/etc/pacman.d/fenrir-signing-key.asc"], progress)
    _chroot(["pacman-key", "--lsign-key", FENRIR_REPO_KEY_FPR], progress)


def copy_skel(progress):
    # pacstrap leaves a bare /etc/skel; copy the live session's own
    # Caelestia-configured skel onto the target instead.
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


# Matches the live session's liveuser groups (useradd -G wheel alone
# misses these); added one at a time so a missing group doesn't fail the install.
USER_GROUPS = ("network", "power", "adm", "uucp", "optical", "rfkill", "video", "storage", "audio", "users")


def create_user(username, full_name, password, progress):
    progress(f"Creating user {username}")
    _chroot(
        ["useradd", "-m", "-G", "wheel", "-s", "/usr/bin/fish", "-c", full_name, username],
        progress,
    )
    for group in USER_GROUPS:
        proc = subprocess.run(
            ["arch-chroot", str(TARGET), "usermod", "-aG", group, username],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            progress(f"Note: couldn't add {username} to group '{group}' (it may not exist on this install) - continuing")
    for account in (username, "root"):
        proc = subprocess.run(
            ["arch-chroot", str(TARGET), "chpasswd"],
            input=f"{account}:{password}\n",
            text=True,
        )
        if proc.returncode != 0:
            raise InstallError(f"Failed to set password for {account}")


def configure_sudo(progress):
    # wheel is commented out in Arch's default sudoers; drop in a file
    # instead of editing it directly. sudo requires exactly 0440 to read it.
    progress("Enabling sudo for the wheel group")
    sudoers_wheel = TARGET / "etc/sudoers.d/wheel"
    sudoers_wheel.write_text("%wheel ALL=(ALL:ALL) ALL\n")
    sudoers_wheel.chmod(0o440)


def configure_kernel_cmdline(root_part, progress):
    # Without this, limine-entry-tool falls back to /proc/cmdline, which
    # under arch-chroot is the live ISO's own boot params, not the target's.
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
    # limine-update writes each kernel's real boot entry into limine.conf;
    # must run after limine-install or it gets clobbered back to a placeholder.
    progress("Generating initramfs and Limine boot entries")
    _chroot(["limine-update"], progress)

    # limine-install/update don't touch this setting; force it last so
    # it isn't clobbered by either call.
    progress("Configuring Limine to boot straight to the desktop")
    limine_conf = TARGET / "boot/limine.conf"
    lines = limine_conf.read_text().splitlines()
    lines = [line for line in lines if not line.strip().startswith("timeout:")]
    lines.insert(0, "timeout: 0")
    limine_conf.write_text("\n".join(lines) + "\n")


ENABLED_SERVICES = ("NetworkManager", "systemd-timesyncd", "bluetooth", "fstrim.timer", "sddm", "ufw")


def enable_services(progress):
    for service in ENABLED_SERVICES:
        progress(f"Enabling {service}")
        _chroot(["systemctl", "enable", service], progress)


def configure_firewall(progress):
    # Flip ENABLED directly rather than `ufw enable`, which would also
    # try to apply the ruleset through netfilter mid-chroot.
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
    # gpg-agent (from pacstrap's keyring setup) can outlive its chroot and
    # keep the target busy; kill stragglers, then fall back to a lazy unmount.
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
    configure_fenrir_repo(progress)
    copy_skel(progress)
    genfstab_target(progress)
    configure_locale(plan.timezone, plan.locale, progress)
    configure_keyboard(plan.keyboard, progress)
    configure_hostname(plan.hostname, progress)
    create_user(plan.username, plan.full_name, plan.password, progress)
    configure_sudo(progress)
    _, root_part = _partition_paths(plan.disk)
    configure_kernel_cmdline(root_part, progress)
    finalize_bootloader(progress)
    enable_services(progress)
    configure_firewall(progress)
    unmount_target(progress)
    progress("Install complete")
