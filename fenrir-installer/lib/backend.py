"""Does the actual install: partitioning, cloning the live system, target configuration.
Runs as root already (launched via pkexec) — no escalation happens here.
"""

import json
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

TARGET = Path("/mnt")
# @swap stands apart because btrfs can't snapshot a subvolume holding an active swapfile.
BTRFS_SUBVOLUMES = ("@", "@home", "@root", "@srv", "@cache", "@tmp", "@log", "@swap")
BTRFS_MOUNTS = {
    "@": "/",
    "@home": "/home",
    "@root": "/root",
    "@srv": "/srv",
    "@cache": "/var/cache",
    "@tmp": "/var/tmp",
    "@log": "/var/log",
    "@swap": "/swap",
}
SWAP_FILE = "swap/swapfile"
# Hibernating needs room for the memory apps hold, not all of RAM; past this, it falls back to suspend.
SWAP_MAX_GIB = 32
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


# rsync --info=progress2 redraws with \r, which text mode turns into thousands
# of lines a second. Matches "  1,234,567  42%  120.00MB/s    0:00:07".
PROGRESS_LINE = re.compile(r"^\s*[\d,]+\s+\d+%")
PROGRESS_INTERVAL = 1.0


def _stream(cmd, progress, **kwargs):
    progress(f"+ {' '.join(cmd)}")
    # stdbuf so output streams live; nice so it doesn't starve the compositor.
    proc = subprocess.Popen(
        ["nice", "-n", "10", "stdbuf", "-oL", "-eL", *cmd],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        **kwargs,
    )
    last_progress = 0.0
    for line in proc.stdout:
        line = line.rstrip()
        if PROGRESS_LINE.match(line):
            now = time.monotonic()
            if now - last_progress < PROGRESS_INTERVAL:
                continue
            last_progress = now
        progress(line)
    proc.wait()
    if proc.returncode != 0:
        raise InstallError(f"{cmd[0]} exited with status {proc.returncode}")


def _chroot(cmd, progress):
    # Drop the LD_PRELOAD stdbuf sets, or it leaks into the chroot.
    _stream(["arch-chroot", str(TARGET), "env", "-u", "LD_PRELOAD", *cmd], progress)


def _boot_medium_disk():
    # The live USB's own disk, so list_disks() can never offer it for wiping.
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
        # Whole-disk media (e.g. optical) have no parent.
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
    boot_disk = _boot_medium_disk()
    return [
        {
            "path": d["path"],
            "size": int(d["size"]),
            "model": (d.get("model") or "").strip(),
        }
        for d in json.loads(out)["blockdevices"]
        if d["type"] == "disk" and not d["name"].startswith(("zram", "loop")) and d["name"] != boot_disk
    ]


def _partition_paths(disk):
    sep = "p" if disk[-1].isdigit() else ""
    return f"{disk}{sep}1", f"{disk}{sep}2"


def partition_and_mount(disk, esp_mib, progress):
    boot_part, root_part = _partition_paths(disk)

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
    # partprobe can return before udev creates the device nodes mkfs needs.
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


# The squashfs as built, without anything the live session has written since.
LIVE_ROOTFS = Path("/run/archiso/airootfs")

# Live-only state that the clone must never carry onto a real system.
LIVE_ONLY_PATHS = (
    "etc/fenrir-packages.x86_64",  # also marks a running live image
    "etc/sddm.conf.d/autologin.conf",
    "etc/mkinitcpio.conf.d/archiso.conf",
    "etc/polkit-1/rules.d/49-nopasswd_global.rules",
    "etc/machine-id",
    "etc/pacman.d/gnupg",
    "etc/ssh/ssh_host_*",  # regenerated on first boot; never share host keys
    "var/cache/pacman/pkg/*",
    "var/lib/pacman/sync/*",
    "var/log/journal/*",
    # Rebuilds the keyring on a tmpfs at every boot, which drops the Fenrir repo key.
    "etc/systemd/system/pacman-init.service",
    "etc/systemd/system/multi-user.target.wants/pacman-init.service",
    "etc/systemd/system/etc-pacman.d-gnupg.mount",
    # sshd with root password login; an install enables sshd itself if it wants it.
    "etc/systemd/system/multi-user.target.wants/sshd.service",
    "etc/ssh/sshd_config.d/10-archiso.conf",
    "etc/systemd/system/getty@tty1.service.d",
    "etc/systemd/system/livecd-*",
    "etc/systemd/system/*.wants/livecd-*",
    "etc/systemd/journald.conf.d/volatile-storage.conf",
    "etc/systemd/logind.conf.d/do-not-suspend.conf",
    "etc/sudoers.d/g_wheel",
    "etc/motd",
    "root/.automated_script.sh",
    "root/.zlogin",
)


def clone_live_rootfs(progress):
    """Copies the live system to disk instead of re-downloading every package."""
    if not LIVE_ROOTFS.is_dir():
        raise InstallError(
            f"{LIVE_ROOTFS} is missing - the installer must run from a booted "
            "Fenrir live image, which is what it copies onto the disk."
        )

    progress("Installing packages by copying the live system")
    excludes = [f"--exclude=/{rel}" for rel in LIVE_ONLY_PATHS]
    _stream(
        ["rsync", "-aHAX", "--numeric-ids", "--info=progress2", *excludes,
         f"{LIVE_ROOTFS}/", f"{TARGET}/"],
        progress,
    )

    # liveuser holds uid 1000; left in place it pushes the real account to 1001
    # and strands a passwordless ghost in wheel.
    if (TARGET / "home/liveuser").exists():
        _chroot(["userdel", "-r", "liveuser"], progress)


# Deliberately kept: VM guest agents, the accessibility stack, gparted and
# network diagnostics.
LIVE_ONLY_PACKAGES = (
    "mkinitcpio-archiso",
    "cachy-chroot", "cloud-init", "darkhttpd",
    "clonezilla", "partclone", "partimage", "refind",
    "memtest86+", "memtest86+-efi",
    "open-iscsi", "nbd", "dmraid",
    "jfsutils", "nilfs-utils", "udftools", "linux-atm",
    "wvdial", "xl2tpd", "rp-pppoe",
    "irssi", "lftp",
)


def remove_live_only_packages(progress):
    # Non-fatal: pacman aborts the whole transaction if anything still depends
    # on one of these, and a slightly bigger install beats a failed one.
    progress("Removing live-only tooling")
    proc = subprocess.run(
        ["arch-chroot", str(TARGET), "pacman", "-Rns", "--noconfirm", *LIVE_ONLY_PACKAGES],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        progress("Note: live-only tooling could not be removed - continuing")


def initialize_keyring(progress):
    # The live keyring is built at boot into the overlay's upper layer, so the
    # clone of the squashfs lowerdir carries none.
    progress("Initializing the pacman keyring")
    _chroot(["sh", "-c", "pacman-key --init && pacman-key --populate"], progress)


# Public half is archiso/airootfs/etc/pacman.d/fenrir-signing-key.asc.
FENRIR_REPO_KEY_FPR = "BE0B53BD597DF2CDB8437E869C17423CED27E4BE"


def configure_fenrir_repo(progress):
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

    pacman_conf = TARGET / "etc/pacman.conf"
    lines = pacman_conf.read_text().splitlines()
    if not any(line.strip() == "[fenrir]" for line in lines):
        anchor = next((i for i, line in enumerate(lines) if line.strip() == "[core]"), None)
        if anchor is None:
            raise InstallError(f"No [core] section in {pacman_conf} to anchor [fenrir] against")
        lines[anchor:anchor] = [
            "[fenrir]",
            "SigLevel = Required",
            "Include = /etc/pacman.d/fenrir-mirrorlist",
            "",
        ]
        pacman_conf.write_text("\n".join(lines) + "\n")

    _chroot(["sh", "-c",
             "pacman-key --add /etc/pacman.d/fenrir-signing-key.asc && "
             f"pacman-key --lsign-key {FENRIR_REPO_KEY_FPR}"], progress)


def genfstab_target(progress):
    progress("Writing fstab")
    result = subprocess.run(
        ["genfstab", "-U", str(TARGET)], check=True, capture_output=True, text=True
    )
    (TARGET / "etc/fstab").write_text(result.stdout)


def _swap_gib(root_part):
    # As big as RAM so a hibernation image fits, up to SWAP_MAX_GIB and a quarter of the disk.
    with open("/proc/meminfo") as meminfo:
        ram_kib = next(int(line.split()[1]) for line in meminfo if line.startswith("MemTotal:"))
    part_bytes = int(subprocess.run(
        ["blockdev", "--getsize64", root_part], check=True, capture_output=True, text=True
    ).stdout)
    return max(1, min(-(-ram_kib // 1024 ** 2), SWAP_MAX_GIB, part_bytes // 4 // 1024 ** 3))


def configure_swap(root_part, progress):
    # zram stays first in line (higher priority); this takes its overflow and hibernation images.
    size_gib = _swap_gib(root_part)
    progress(f"Creating a {size_gib} GiB swap file")
    _stream(
        ["btrfs", "filesystem", "mkswapfile", "--size", f"{size_gib}g", "--uuid", "clear",
         str(TARGET / SWAP_FILE)],
        progress,
    )
    with open(TARGET / "etc/fstab", "a") as fstab:
        fstab.write(f"/{SWAP_FILE} none swap defaults 0 0\n")


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


KBD_MODEL_MAP = Path("/usr/share/systemd/kbd-model-map")
SKEL_HYPR_VARS = "etc/skel/.config/caelestia/hypr-vars.lua"


def _console_keymap(layout):
    # X11 layouts and console keymaps are different namespaces ("se" vs
    # "sv-latin1"); systemd ships the table that maps between them.
    try:
        lines = KBD_MODEL_MAP.read_text().splitlines()
    except OSError:
        return layout
    rows = [l.split() for l in lines if l.strip() and not l.startswith("#")]
    for row in rows:
        if len(row) >= 2 and row[1] == layout:
            return row[0]
    for row in rows:
        if len(row) >= 2 and row[1].split(",")[0] == layout:
            return row[0]
    return layout


def configure_keyboard(layout, progress):
    keymap = _console_keymap(layout)
    progress(f"Setting keyboard layout to {layout} (console keymap {keymap})")
    (TARGET / "etc/vconsole.conf").write_text(f"KEYMAP={keymap}\n")
    xorg_dir = TARGET / "etc/X11/xorg.conf.d"
    xorg_dir.mkdir(parents=True, exist_ok=True)
    (xorg_dir / "00-keyboard.conf").write_text(
        'Section "InputClass"\n'
        '    Identifier "system-keyboard"\n'
        '    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{layout}"\n'
        "EndSection\n"
    )

    # Hyprland ignores xorg.conf.d; written into skel so useradd -m copies it.
    hypr_vars = TARGET / SKEL_HYPR_VARS
    hypr_vars.parent.mkdir(parents=True, exist_ok=True)
    hypr_vars.write_text('return {\n    kbLayout = "%s",\n}\n' % layout)


AUTOLOGIN_SESSION = "hyprland.desktop"


def configure_autologin(username, progress):
    # Boots straight into a session that fenrir-splash locks. Relogin=false: once
    # per boot, so if the session ever ends sddm shows its normal greeter.
    progress("Configuring automatic login")
    conf_dir = TARGET / "etc/sddm.conf.d"
    conf_dir.mkdir(parents=True, exist_ok=True)
    (conf_dir / "autologin.conf").write_text(
        "[Autologin]\n"
        f"User={username}\n"
        f"Session={AUTOLOGIN_SESSION}\n"
        "Relogin=false\n"
    )

    # Set explicitly rather than trusting sddm.service to carry an Alias.
    dm = TARGET / "etc/systemd/system/display-manager.service"
    dm.parent.mkdir(parents=True, exist_ok=True)
    dm.unlink(missing_ok=True)
    dm.symlink_to("/usr/lib/systemd/system/sddm.service")


def configure_hostname(hostname, progress):
    progress(f"Setting hostname to {hostname}")
    (TARGET / "etc/hostname").write_text(f"{hostname}\n")
    (TARGET / "etc/hosts").write_text(
        "127.0.0.1\tlocalhost\n"
        "::1\t\tlocalhost\n"
        f"127.0.1.1\t{hostname}\n"
    )


# Matches the live session's liveuser groups; useradd -G wheel alone misses these.
USER_GROUPS = ("network", "power", "adm", "uucp", "optical", "rfkill", "video", "storage", "audio", "users")


def create_user(username, full_name, password, progress):
    progress(f"Creating user {username}")
    _chroot(
        ["useradd", "-m", "-G", "wheel", "-s", "/usr/bin/fish", "-c", full_name, username],
        progress,
    )
    # One usermod for the groups that exist, so a missing one can't fail the install.
    existing = set()
    group_file = TARGET / "etc/group"
    if group_file.exists():
        existing = {l.split(":", 1)[0] for l in group_file.read_text().splitlines() if ":" in l}
    wanted = [g for g in USER_GROUPS if g in existing]
    missing = [g for g in USER_GROUPS if g not in existing]
    if missing:
        progress(f"Note: groups not on this install, skipping: {', '.join(missing)}")
    if wanted:
        _chroot(["usermod", "-aG", ",".join(wanted), username], progress)
    for account in (username, "root"):
        proc = subprocess.run(
            ["arch-chroot", str(TARGET), "chpasswd"],
            input=f"{account}:{password}\n",
            text=True,
        )
        if proc.returncode != 0:
            raise InstallError(f"Failed to set password for {account}")


def configure_sudo(progress):
    # Arch's sudoers has wheel commented out; sudo requires exactly 0440.
    progress("Enabling sudo for the wheel group")
    sudoers_wheel = TARGET / "etc/sudoers.d/wheel"
    sudoers_wheel.write_text("%wheel ALL=(ALL:ALL) ALL\n")
    sudoers_wheel.chmod(0o440)


def configure_polkit(progress):
    # Clock and firewall changes from Nexus skip the prompt for a local, active
    # wheel user. The systemd grant is scoped to firewalld.service only.
    progress("Allowing clock and firewall changes without a password")
    rules_dir = TARGET / "etc/polkit-1/rules.d"
    rules_dir.mkdir(parents=True, exist_ok=True)
    (rules_dir / "50-fenrir.rules").write_text(
        "polkit.addRule(function(action, subject) {\n"
        '    if (!subject.isInGroup("wheel") || !subject.local || !subject.active)\n'
        "        return polkit.Result.NOT_HANDLED;\n"
        '    if (action.id.indexOf("org.freedesktop.timedate1.") === 0 ||\n'
        '        action.id === "org.fedoraproject.FirewallD1.info" ||\n'
        '        action.id === "org.fedoraproject.FirewallD1.config.info" ||\n'
        '        action.id === "org.fedoraproject.FirewallD1.config") {\n'
        "        return polkit.Result.YES;\n"
        "    }\n"
        '    if ((action.id === "org.freedesktop.systemd1.manage-units" ||\n'
        '         action.id === "org.freedesktop.systemd1.manage-unit-files") &&\n'
        '        action.lookup("unit") === "firewalld.service") {\n'
        "        return polkit.Result.YES;\n"
        "    }\n"
        "    return polkit.Result.NOT_HANDLED;\n"
        "});\n"
    )


def configure_plymouth(progress):
    # The theme and plymouthd.conf arrive with the clone; only the initramfs hook
    # doesn't, since the live image's HOOKS live in the excluded archiso.conf.
    if not (TARGET / "usr/share/plymouth/themes/fenrir").is_dir():
        progress("Skipping boot splash — theme missing from the live image")
        return

    progress("Setting up the boot splash")
    # Must precede finalize_bootloader, which regenerates the initramfs. Anchored
    # on systemd or udev, since the default systemd-based HOOKS has no "udev".
    mkinitcpio_conf = TARGET / "etc/mkinitcpio.conf"
    lines = mkinitcpio_conf.read_text().splitlines()
    for i, line in enumerate(lines):
        if not line.startswith("HOOKS="):
            continue
        if "plymouth" in line:
            break
        for anchor in ("systemd", "udev"):
            if re.search(rf"\b{anchor}\b", line):
                lines[i] = re.sub(rf"\b{anchor}\b", f"{anchor} plymouth", line, count=1)
                break
        else:
            raise InstallError(
                f"No systemd or udev hook in {mkinitcpio_conf}; can't place the plymouth hook"
            )
        break
    else:
        raise InstallError(f"No HOOKS= line in {mkinitcpio_conf}")
    mkinitcpio_conf.write_text("\n".join(lines) + "\n")


def configure_kernel_cmdline(root_part, progress):
    # Otherwise limine-entry-tool reads /proc/cmdline, which under arch-chroot is
    # the live ISO's boot params rather than the target's.
    progress("Writing kernel command line")
    uuid = subprocess.run(
        ["blkid", "-s", "UUID", "-o", "value", root_part],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    kernel_dir = TARGET / "etc/kernel"
    kernel_dir.mkdir(parents=True, exist_ok=True)
    (kernel_dir / "cmdline").write_text(
        f"rw root=UUID={uuid} rootflags=subvol=@ quiet splash loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0\n"
    )


BOOTLOADER_STAGE = "opt/fenrir-bootloader"


def install_bootloader_packages(progress):
    # limine is kept out of the live image (its hooks need a real ESP), so its
    # packages ride along on the ISO and are installed once the ESP is mounted.
    stage = TARGET / BOOTLOADER_STAGE
    packages = sorted(stage.glob("*.pkg.tar.zst")) if stage.is_dir() else []
    if not packages:
        raise InstallError(f"No bootloader packages staged in /{BOOTLOADER_STAGE}")

    progress("Installing the bootloader")
    _chroot(
        ["pacman", "-U", "--noconfirm", *[f"/{BOOTLOADER_STAGE}/{p.name}" for p in packages]],
        progress,
    )
    shutil.rmtree(stage, ignore_errors=True)


def configure_snapshots(progress):
    # Before finalize_bootloader, whose initramfs rebuild picks up the overlay hook this adds.
    progress("Setting up update snapshots")
    _chroot(["/usr/lib/fenrir/fenrir-setup-snapshots", "--no-initramfs"], progress)


def finalize_bootloader(progress):
    progress("Installing Limine")
    _chroot(["limine-install"], progress)
    # limine-update writes the real per-kernel entries, so it must run last or
    # limine-install clobbers them back to a placeholder.
    progress("Generating initramfs and Limine boot entries")
    _chroot(["limine-update"], progress)

    progress("Configuring Limine to boot straight to the desktop")
    limine_conf = TARGET / "boot/limine.conf"
    lines = limine_conf.read_text().splitlines()
    lines = [line for line in lines if not line.strip().startswith(("timeout:", "quiet:"))]
    # Quiet, or Limine prints a line each for the kernel and initramfs ahead of the splash.
    lines[:0] = ["timeout: 0", "quiet: yes"]
    limine_conf.write_text("\n".join(lines) + "\n")


ENABLED_SERVICES = ("NetworkManager", "systemd-timesyncd", "bluetooth", "fstrim.timer", "sddm", "firewalld")


def enable_services(progress):
    progress(f"Enabling {', '.join(ENABLED_SERVICES)}")
    _chroot(["systemctl", "enable", *ENABLED_SERVICES], progress)


# firewalld's stock public zone minus ssh (sshd only runs on the live ISO), plus
# the desktop discovery services that would otherwise fail silently.
DEFAULT_ZONE_SERVICES = ("dhcpv6-client", "mdns", "ssdp", "kdeconnect", "steam-streaming")


def configure_firewall(progress):
    # A zone override in /etc/firewalld/zones needs no running daemon, so it
    # works in the chroot where firewall-cmd would not.
    progress("Enabling firewall")

    conf = TARGET / "etc/firewalld/firewalld.conf"
    if not conf.exists():
        raise InstallError(f"{conf} is missing — is firewalld installed?")
    lines = conf.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("DefaultZone="):
            lines[i] = "DefaultZone=public"
            break
    else:
        lines.append("DefaultZone=public")
    conf.write_text("\n".join(lines) + "\n")

    services = "\n".join(f'  <service name="{s}"/>' for s in DEFAULT_ZONE_SERVICES)
    zones_dir = TARGET / "etc/firewalld/zones"
    zones_dir.mkdir(parents=True, exist_ok=True)
    (zones_dir / "public.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<zone>\n"
        "  <short>Public</short>\n"
        "  <description>Only selected incoming connections are accepted."
        " Outgoing traffic is unrestricted.</description>\n"
        f"{services}\n"
        "  <forward/>\n"
        "</zone>\n"
    )


def unmount_target(progress):
    progress("Unmounting target")
    # gpg-agent from pacman-key can outlive its chroot and keep the target busy.
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
    clone_live_rootfs(progress)
    remove_live_only_packages(progress)
    initialize_keyring(progress)
    configure_fenrir_repo(progress)
    _, root_part = _partition_paths(plan.disk)
    genfstab_target(progress)
    configure_swap(root_part, progress)
    configure_locale(plan.timezone, plan.locale, progress)
    configure_keyboard(plan.keyboard, progress)
    configure_autologin(plan.username, progress)
    configure_hostname(plan.hostname, progress)
    create_user(plan.username, plan.full_name, plan.password, progress)
    configure_sudo(progress)
    configure_polkit(progress)
    configure_plymouth(progress)
    configure_kernel_cmdline(root_part, progress)
    install_bootloader_packages(progress)
    configure_snapshots(progress)
    finalize_bootloader(progress)
    enable_services(progress)
    configure_firewall(progress)
    unmount_target(progress)
    progress("Install complete")
