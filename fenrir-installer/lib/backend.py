"""Does the actual install: partitioning, pacstrap, target configuration.
Runs as root already (launched via pkexec) — no escalation happens here.
"""

import re
import shutil
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


# rsync --info=progress2 redraws with a carriage return, and Python's text
# mode turns every \r into a line, so an unthrottled copy emits thousands of
# these a second. Matches "  1,234,567  42%  120.00MB/s    0:00:07".
PROGRESS_LINE = re.compile(r"^\s*[\d,]+\s+\d+%")
PROGRESS_INTERVAL = 1.0


def _stream(cmd, progress, **kwargs):
    progress(f"+ {' '.join(cmd)}")
    # stdbuf forces line buffering so pacstrap's progress streams live;
    # nice stops it starving the compositor.
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
        # Rate-limit redraws only; anything else (errors included) goes through.
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


# The overlay lowerdir: the squashfs exactly as built, without whatever the
# live session has written since boot.
LIVE_ROOTFS = Path("/run/archiso/airootfs")

# Live-only state that must never reach an installed system.
LIVE_ONLY_PATHS = (
    "etc/fenrir-packages.x86_64",  # also what gates the installer's autostart
    "etc/sddm.conf.d/autologin.conf",
    "etc/mkinitcpio.conf.d/archiso.conf",  # archiso HOOKS; the target needs its own
    "etc/polkit-1/rules.d/49-nopasswd_global.rules",  # blanket wheel rule
    "etc/machine-id",  # must be unique per machine
    "etc/pacman.d/gnupg",  # local signing key must be per-machine, like ssh host keys
    "opt/fenrir-local-repo",  # ~130MB of packages, and [fenrir-local] goes with it
)


def clone_live_rootfs(progress):
    """Copies the live system to disk instead of re-downloading every package."""
    if not LIVE_ROOTFS.is_dir():
        progress("Installing packages (no live root filesystem found)")
        pacstrap_target(progress)
        return

    progress("Installing packages by copying the live system")
    _stream(
        ["rsync", "-aHAX", "--numeric-ids", "--info=progress2",
         f"{LIVE_ROOTFS}/", f"{TARGET}/"],
        progress,
    )
    _scrub_live_state(progress)


def initialize_keyring(progress):
    # The clone comes from /run/archiso/airootfs, the read-only squashfs
    # lowerdir - but the live keyring is built at boot by pacman-init.service
    # into the overlay's upper layer, so the target inherits none at all and
    # every pacman-key call fails its permission check. Idempotent, so it is
    # safe on the pacstrap fallback path too.
    progress("Initializing the pacman keyring")
    _chroot(["pacman-key", "--init"], progress)
    _chroot(["pacman-key", "--populate"], progress)


def _remove_pacman_section(pacman_conf, section):
    lines = pacman_conf.read_text().splitlines()
    try:
        start = lines.index(f"[{section}]")
    except ValueError:
        return
    end = start + 1
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1  # keep the blank line that separated the next section
    del lines[start:end]
    pacman_conf.write_text("\n".join(lines) + "\n")


def _scrub_live_state(progress):
    progress("Removing live-session state")

    for rel in LIVE_ONLY_PATHS:
        path = TARGET / rel
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)

    # liveuser holds uid 1000, so leaving it would push the real account to
    # 1001 and strand a passwordless-login ghost in wheel/autologin.
    if (TARGET / "home/liveuser").exists():
        _chroot(["userdel", "-r", "liveuser"], progress)

    _remove_pacman_section(TARGET / "etc/pacman.conf", "fenrir-local")

    # Regenerated on first boot; shared host keys across installs would be bad.
    ssh_dir = TARGET / "etc/ssh"
    if ssh_dir.is_dir():
        for key in ssh_dir.glob("ssh_host_*"):
            key.unlink(missing_ok=True)

    for rel in ("var/cache/pacman/pkg", "var/lib/pacman/sync", "var/log/journal"):
        path = TARGET / rel
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
            path.mkdir(parents=True, exist_ok=True)


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

    # Anchored on [core]: it's guaranteed present in pacman's own default
    # template pacstrap just laid down, unlike the CachyOS sections.
    pacman_conf = TARGET / "etc/pacman.conf"
    lines = pacman_conf.read_text().splitlines()
    if not any(line.strip() == "[fenrir]" for line in lines):
        # A bare next() raises StopIteration, which surfaces through cli.py
        # as "INSTALL_ERROR:" with no message at all - miserable to debug
        # from a progress log.
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

    # initialize_keyring() has already built a fresh keyring for the target,
    # so pacman-key has something to add to.
    _chroot(["pacman-key", "--add", "/etc/pacman.d/fenrir-signing-key.asc"], progress)
    _chroot(["pacman-key", "--lsign-key", FENRIR_REPO_KEY_FPR], progress)


# pacstrap lays down pacman's stock pacman.conf, and no CachyOS package
# adds its repos (they ship mirrorlist files only) - so without this an
# installed system can never update its kernel, nvidia or any cachyos pkg.
CACHYOS_REPOS = ("cachyos-v3", "cachyos-extra-v3", "cachyos-core-v3", "cachyos")


def configure_cachyos_repos(progress):
    progress("Configuring the CachyOS package repositories")

    pacman_conf = TARGET / "etc/pacman.conf"
    lines = pacman_conf.read_text().splitlines()
    if any(line.strip() == "[cachyos-v3]" for line in lines):
        return

    anchor = next((i for i, line in enumerate(lines) if line.strip() == "[core]"), None)
    if anchor is None:
        raise InstallError(f"No [core] section in {pacman_conf} to anchor the CachyOS repos against")

    block = []
    for repo in CACHYOS_REPOS:
        generic = repo == "cachyos"
        mirrorlist = "cachyos-mirrorlist" if generic else "cachyos-v3-mirrorlist"
        if not (TARGET / "etc/pacman.d" / mirrorlist).exists():
            raise InstallError(f"/etc/pacman.d/{mirrorlist} is missing from the target")
        # Not cdn77 (CachyOS's default first mirror): it 404s on every
        # filename containing '+', and pacman then drops it mid-transaction
        # and falls through to mirrors serving stale payloads.
        arch = "$arch" if generic else "$arch_v3"
        block += [f"[{repo}]", "SigLevel = Optional TrustAll",
                  f"Server = https://mirror.cachyos.org/repo/{arch}/$repo",
                  f"Include = /etc/pacman.d/{mirrorlist}", ""]
    lines[anchor:anchor] = block
    pacman_conf.write_text("\n".join(lines) + "\n")


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


KBD_MODEL_MAP = Path("/usr/share/systemd/kbd-model-map")
SKEL_HYPR_VARS = "etc/skel/.config/caelestia/hypr-vars.lua"
GREETER_LAYOUT_CONF = "etc/greetd/hyprland-layout.conf"


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

    # Hyprland ignores xorg.conf.d, so without this the desktop stays on "us".
    # Written into skel because create_user's useradd -m copies it from there.
    hypr_vars = TARGET / SKEL_HYPR_VARS
    hypr_vars.parent.mkdir(parents=True, exist_ok=True)
    hypr_vars.write_text('return {\n    kbLayout = "%s",\n}\n' % layout)

    # The greeter is a separate user running its own bare Hyprland, so it
    # needs the layout independently - otherwise the login screen is always
    # us and anyone else mistypes their password with no clue why.
    greeter_conf = TARGET / GREETER_LAYOUT_CONF
    greeter_conf.parent.mkdir(parents=True, exist_ok=True)
    greeter_conf.write_text("input {\n    kb_layout = %s\n}\n" % layout)


# The live image overlays /etc/greetd/config.toml with an autologin section
# for liveuser; the package keeps an untouched copy here for the target.
GREETER_PRISTINE_CONF = Path("/usr/share/fenrir-greeter/config.toml")


def configure_greeter(progress):
    # The clone copies the live config verbatim, autologin and all, which on a
    # real machine would log anyone straight in as a user that no longer
    # exists. Overwrite it rather than scrub it, so the target always ends up
    # with a working greeter config.
    target_conf = TARGET / "etc/greetd/config.toml"
    if not GREETER_PRISTINE_CONF.exists():
        progress("Skipping greeter config - fenrir-greeter is not installed")
        return

    progress("Configuring the login screen")
    target_conf.parent.mkdir(parents=True, exist_ok=True)
    target_conf.write_text(GREETER_PRISTINE_CONF.read_text())

    # Point display-manager.service at greetd explicitly rather than trusting
    # greetd.service to carry an Alias for it. sddm stays installed as the way
    # back in: "systemctl enable --now sddm" from a TTY if the greeter fails.
    dm = TARGET / "etc/systemd/system/display-manager.service"
    dm.parent.mkdir(parents=True, exist_ok=True)
    dm.unlink(missing_ok=True)
    dm.symlink_to("/usr/lib/systemd/system/greetd.service")


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


def configure_polkit(progress):
    # Clock and firewall changes from Nexus don't prompt: a local, active
    # wheel user can already sudo anything, so this removes friction rather
    # than a barrier. Only the three FirewallD actions the page actually
    # uses are granted - .direct and .policies stay at auth_admin_keep.
    # The systemd grant is scoped to firewalld.service; if systemd doesn't
    # supply the "unit" detail the rule just won't match and the user gets
    # the normal prompt, so it can never over-grant.
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
    # The package is pacstrapped, but none of its config is - the theme,
    # plymouthd.conf and the mkinitcpio hook all live in the live image's
    # own airootfs, so an install gets Plymouth with nothing configured.
    live_theme = Path("/usr/share/plymouth/themes/fenrir")
    if not live_theme.is_dir():
        progress("Skipping boot splash — theme missing from the live image")
        return

    progress("Setting up the boot splash")
    target_theme = TARGET / "usr/share/plymouth/themes/fenrir"
    target_theme.mkdir(parents=True, exist_ok=True)
    _stream(["cp", "-a", f"{live_theme}/.", f"{target_theme}/"], progress)

    plymouth_dir = TARGET / "etc/plymouth"
    plymouth_dir.mkdir(parents=True, exist_ok=True)
    (plymouth_dir / "plymouthd.conf").write_text("[Daemon]\nTheme=fenrir\n")

    # Must happen before finalize_bootloader, which regenerates the
    # initramfs - the hook has to be in HOOKS by then or the splash never
    # makes it into the image.
    # The hook goes after whichever initrd flavour is in use. mkinitcpio's
    # current default is systemd-based and has no "udev" token at all, so
    # anchoring only on udev silently did nothing and the splash never
    # reached the installed system.
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
    (kernel_dir / "cmdline").write_text(
        f"rw root=UUID={uuid} rootflags=subvol=@ quiet splash loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0\n"
    )


BOOTLOADER_STAGE = "opt/fenrir-bootloader"


def install_bootloader_packages(progress):
    # limine is missing from the live image on purpose (see util-iso.sh), so
    # the clone inherits that gap and limine-install would not exist. The
    # package files ride along on the ISO instead; by now the target has a
    # real ESP mounted, which is the thing their hooks need.
    stage = TARGET / BOOTLOADER_STAGE
    packages = sorted(stage.glob("*.pkg.tar.zst")) if stage.is_dir() else []
    if not packages:
        # The pacstrap fallback path installs limine from the package list.
        progress("No staged bootloader packages, assuming limine is installed")
        return

    progress("Installing the bootloader")
    _chroot(
        ["pacman", "-U", "--noconfirm", *[f"/{BOOTLOADER_STAGE}/{p.name}" for p in packages]],
        progress,
    )
    shutil.rmtree(stage, ignore_errors=True)


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


ENABLED_SERVICES = ("NetworkManager", "systemd-timesyncd", "bluetooth", "fstrim.timer", "greetd", "firewalld")


def enable_services(progress):
    for service in ENABLED_SERVICES:
        progress(f"Enabling {service}")
        _chroot(["systemctl", "enable", service], progress)


# Dropped vs firewalld's stock public zone: ssh. sshd is enabled only on the
# live ISO, never on an installed system, so port 22 would be pure attack
# surface. The rest are the desktop cases that otherwise fail silently later -
# printer/device discovery, casting, phone pairing, Steam Remote Play. Each is
# inert until the matching app is actually installed and listening.
DEFAULT_ZONE_SERVICES = ("dhcpv6-client", "mdns", "ssdp", "kdeconnect", "steam-streaming")


def configure_firewall(progress):
    # Written as a zone override in /etc/firewalld/zones, which firewalld
    # reads in preference to /usr/lib/firewalld/zones - no daemon needed, so
    # this works inside the chroot where firewall-cmd would not.
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
    clone_live_rootfs(progress)
    initialize_keyring(progress)
    configure_fenrir_repo(progress)
    configure_cachyos_repos(progress)
    copy_skel(progress)
    genfstab_target(progress)
    configure_locale(plan.timezone, plan.locale, progress)
    configure_keyboard(plan.keyboard, progress)
    configure_greeter(progress)
    configure_hostname(plan.hostname, progress)
    create_user(plan.username, plan.full_name, plan.password, progress)
    configure_sudo(progress)
    configure_polkit(progress)
    configure_plymouth(progress)
    _, root_part = _partition_paths(plan.disk)
    configure_kernel_cmdline(root_part, progress)
    install_bootloader_packages(progress)
    finalize_bootloader(progress)
    enable_services(progress)
    configure_firewall(progress)
    unmount_target(progress)
    progress("Install complete")
