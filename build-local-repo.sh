#!/usr/bin/env bash
# Builds the AUR and Fenrir packages into local-repo/, so the ISO build never
# needs AUR access. Run before ./buildiso.sh.
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$src_dir/tools/fenrir-packages.sh"
work_dir="${src_dir}/aur-build"
repo_dir="$fenrir_repo_dir"
chroot_dir="$fenrir_chroot_dir"
repo_name="fenrir-local"
# Generic x86-64 flags like Arch's own builds: -march=native output can SIGILL on other CPUs.
makepkg_conf="/usr/share/devtools/makepkg.conf.d/x86_64.conf"

mkdir -p "$work_dir" "$repo_dir"

repo_db="${repo_dir}/${repo_name}.db.tar.gz"

ensure_repo_db() {
    if [[ ! -e "$repo_db" ]]; then
        # repo-add refuses to create a db with zero packages; bootstrap an
        # empty tar.gz plus the ".db" symlink pacman expects by hand.
        tar -czf "$repo_db" -T /dev/null
        ln -sf "$(basename "$repo_db")" "${repo_dir}/${repo_name}.db"
    fi
}

ensure_chroot() {
    if [[ ! -d "$chroot_dir/root" ]]; then
        echo "==> Creating clean build chroot at $chroot_dir"
        mkdir -p "$chroot_dir"
        # caelestia-shell's build() step git-clones a module via CMake
        # FetchContent; base-devel alone doesn't include git.
        sudo mkarchroot -C "$src_dir/archiso/pacman.conf" -M "$makepkg_conf" "$chroot_dir/root" base-devel git
    fi

    # Point the chroot at CachyOS's repos (for repo deps) and our growing
    # local repo (for cross-deps between the AUR packages built here).
    if ! grep -q "^\[${repo_name}\]" "$chroot_dir/root/etc/pacman.conf" 2>/dev/null; then
        sudo tee -a "$chroot_dir/root/etc/pacman.conf" >/dev/null <<EOC

[${repo_name}]
SigLevel = Optional TrustAll
Server = file://${repo_dir}
EOC
    fi
    if ! grep -q "^\[cachyos\]" "$chroot_dir/root/etc/pacman.conf" 2>/dev/null; then
        sudo sed -i "/^\[core\]/i [cachyos]\nServer = https://mirror.cachyos.org/repo/\$arch/\$repo\n" \
            "$chroot_dir/root/etc/pacman.conf"
    fi

    # -M also replaces makepkg.conf.d/ in older chroots. Reinstalling x86_64_v3 builds swaps in generic
    # ones (their crt*.o and libgcc.a end up in every package); -Syu syncs the dbs the Qt key reads.
    local -a v3_pkgs=()
    mapfile -t v3_pkgs < <(chroot_v3_pkgs)
    sudo arch-nspawn -M "$makepkg_conf" "$chroot_dir/root" pacman -Syu --noconfirm "${v3_pkgs[@]}"
    if grep -qsrE '(march|mtune|target-cpu)=native' "$chroot_dir/root/etc/makepkg.conf" "$chroot_dir/root/etc/makepkg.conf.d" ||
       [[ -n "$(chroot_v3_pkgs)" ]]; then
        echo "==> The build chroot still has CPU-specific flags or packages; delete $chroot_dir to recreate it." >&2
        exit 1
    fi
}

chroot_v3_pkgs() {
    awk '/^%NAME%$/ { getline; name = $0 } /^%ARCH%$/ { getline; if ($0 == "x86_64_v3") print name }' \
        "$chroot_dir"/root/var/lib/pacman/local/*/desc
}

build_one() {
    local pkg="$1" build_root="$work_dir/$1" src="${fenrir_pkg_src[$1]:-}" reason status=0 key f
    reason="$(pkg_check_current "$pkg")" || status=$?
    if (( status == 0 )); then
        echo "==> $pkg already built and up to date, skipping"
        return
    fi
    (( status == 1 )) || exit 1
    echo "==> $reason, rebuilding"
    key="$(pkg_key "$pkg")"

    rm -rf "$build_root"
    if [[ -z "$src" ]]; then
        if [[ -n "${fenrir_aur_pins[$pkg]:-}" ]]; then
            # A pinned commit needs full history; these repos are a few KB.
            git clone "https://aur.archlinux.org/${pkg}.git" "$build_root"
            git -C "$build_root" checkout "${fenrir_aur_pins[$pkg]}"
        else
            git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$build_root"
        fi
    else
        [[ "$src" == /* ]] || src="$src_dir/$src"
        mkdir -p "$build_root"
        cp -r "$src"/* "$build_root"/
    fi

    stamp_version "$pkg" "$build_root" "$(date +%Y%m%d%H%M)"
    if declare -F "splice_${pkg//-/_}" >/dev/null; then
        "splice_${pkg//-/_}" "$build_root"
    fi

    echo "==> Building $pkg"
    (
        cd "$build_root"
        # -u: sync/upgrade the chroot first so it can see newly repo-add'ed local pkgs
        makechrootpkg -c -u -r "$chroot_dir" -- --noconfirm
    )

    # Only $pkg itself: the generic config's debug option also makes $pkg-debug.
    local -a built=()
    mapfile -t built < <(pkg_files "$build_root" "$pkg")
    if (( ${#built[@]} != 1 )); then
        echo "==> Expected one $pkg package in $build_root, found ${#built[@]}." >&2
        exit 1
    fi
    while IFS= read -r f; do rm -f "$f"; done < <(pkg_files "$repo_dir" "$pkg")
    cp "${built[0]}" "$repo_dir"/
    repo-add "$repo_db" "$repo_dir/${built[0]##*/}"
    write_pkg_marker "$pkg" "$key" "$repo_dir/${built[0]##*/}"
}

ensure_repo_db
ensure_chroot

if [[ ! -d "$fenrir_user_home/caelestia" ]]; then
    git clone https://github.com/caelestia-dots/caelestia.git "$fenrir_user_home/caelestia"
fi

for pkg in "${fenrir_build_order[@]}"; do
    build_one "$pkg"
done

echo "==> Done. Built packages are in $repo_dir"
ls -1 "$repo_dir"/*.pkg.tar.zst
