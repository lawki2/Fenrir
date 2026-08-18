#!/usr/bin/env bash
# Builds the AUR-only packages Fenrir needs (Caelestia + its uncommon deps)
# into a local pacman repo, so the archiso build never needs AUR/makepkg
# access at ISO-build time. Run this once (or whenever these packages need
# updating), before ./buildiso.sh.
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work_dir="${src_dir}/aur-build"
repo_dir="${src_dir}/local-repo"
chroot_dir="${work_dir}/chroot"
repo_name="fenrir-local"

mkdir -p "$work_dir" "$repo_dir"

# Packages with no interdependencies among themselves, build first.
independent_aur_pkgs=(qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf zen-browser-bin)
# Depends on packages built in the previous stage.
caelestia_aur_pkgs=(caelestia-cli caelestia-shell)

repo_db="${repo_dir}/${repo_name}.db.tar.gz"

ensure_repo_db() {
    if [[ ! -e "$repo_db" ]]; then
        # repo-add refuses to create a db with zero packages (exits 0 without
        # writing anything!), so bootstrap an empty-but-valid tar.gz by hand.
        # pacman resolves the repo via the stable "<repo>.db" symlink that
        # repo-add would normally create alongside it, so do that too.
        tar -czf "$repo_db" -T /dev/null
        ln -sf "$(basename "$repo_db")" "${repo_dir}/${repo_name}.db"
    fi
}

ensure_chroot() {
    if [[ ! -d "$chroot_dir/root" ]]; then
        echo "==> Creating clean build chroot at $chroot_dir"
        mkdir -p "$chroot_dir"
        # git is needed at build time too, not just for cloning PKGBUILDs on
        # the host. caelestia-shell's own build() step git clones a module
        # (M3Shapes) through CMake FetchContent, and base-devel alone does
        # not include git.
        sudo mkarchroot "$chroot_dir/root" base-devel git
    fi

    # Point the chroot at CachyOS's repos (for repo deps) and our growing
    # local repo (for cross-deps between the AUR packages built here).
    if ! grep -q "^\[${repo_name}\]" "$chroot_dir/root/etc/pacman.conf" 2>/dev/null; then
        sudo tee -a "$chroot_dir/root/etc/pacman.conf" >/dev/null <<EOF

[${repo_name}]
SigLevel = Optional TrustAll
Server = file://${repo_dir}
EOF
    fi
    if ! grep -q "^\[cachyos\]" "$chroot_dir/root/etc/pacman.conf" 2>/dev/null; then
        sudo sed -i "/^\[core\]/i [cachyos]\nServer = https://mirror.cachyos.org/repo/\$arch/\$repo\n" \
            "$chroot_dir/root/etc/pacman.conf"
    fi
}

build_one() {
    local pkg="$1" src="$2" # src: "aur" or an absolute path to a local PKGBUILD dir
    local build_root="$work_dir/$pkg"

    if compgen -G "$repo_dir/${pkg}-*.pkg.tar.zst" >/dev/null; then
        echo "==> $pkg already built, skipping (delete $repo_dir/${pkg}-*.pkg.tar.zst to rebuild)"
        return
    fi

    rm -rf "$build_root"
    if [[ "$src" == "aur" ]]; then
        git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$build_root"
    else
        mkdir -p "$build_root"
        cp -r "$src"/* "$build_root"/
    fi

    if [[ "$pkg" == "caelestia-shell" ]]; then
        # caelestia-shell's own PKGBUILD depends on quickshell-git specifically.
        # CachyOS's quickshell-git repo build is a stale snapshot that predates
        # quickshell's "DefaultEnv" pragma support, which the current shell.qml
        # requires to even launch. CachyOS's plain "quickshell" package is a
        # newer, actively rebuilt release with that support, so build against
        # that instead.
        sed -i "s/'quickshell-git'/'quickshell'/" "$build_root/PKGBUILD"

        # Ship Fenrir's own default wallpaper instead of upstream Caelestia's.
        # Wallpapers.qml's fallback (used whenever no per-user wallpaper state
        # exists yet, i.e. every fresh live/installed user) is hardcoded to
        # this exact packaged path with no config override point, so the only
        # way to change it is to replace the file the package itself installs
        # — a plain airootfs overlay can't work here since mkarchiso copies
        # airootfs *before* pacstrap, so pacstrap would just clobber it back.
        cp "$src_dir/assets/wallpaper.webp" "$build_root/fenrir-wallpaper.webp"
        sed -i '/DESTDIR="\$pkgdir" cmake --install build/a\    install -Dm644 "$startdir/fenrir-wallpaper.webp" "$pkgdir/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"' \
            "$build_root/PKGBUILD"
    fi

    echo "==> Building $pkg"
    (
        cd "$build_root"
        # -u: sync/upgrade the chroot first so it can see newly repo-add'ed local pkgs
        makechrootpkg -c -u -r "$chroot_dir" -- --noconfirm
    )

    cp "$build_root"/*.pkg.tar.zst "$repo_dir"/
    repo-add "$repo_db" "$repo_dir"/"${pkg}"-*.pkg.tar.zst
}

ensure_repo_db
ensure_chroot

for pkg in "${independent_aur_pkgs[@]}"; do
    build_one "$pkg" aur
done

for pkg in "${caelestia_aur_pkgs[@]}"; do
    build_one "$pkg" aur
done

# caelestia-meta itself isn't published on AUR. It's built from the
# PKGBUILD at ~/caelestia, cloned fresh here if it's not already present
# (e.g. in CI), or kept in sync via git pull there otherwise.
if [[ ! -d "$HOME/caelestia" ]]; then
    git clone https://github.com/caelestia-dots/caelestia.git "$HOME/caelestia"
fi
build_one "caelestia-meta" "$HOME/caelestia"

# fenrir-installer is Fenrir's own package, not on AUR either. Its PKGBUILD
# lives in this repo.
build_one "fenrir-installer" "$src_dir/fenrir-installer"

echo "==> Done. Built packages are in $repo_dir"
ls -1 "$repo_dir"/*.pkg.tar.zst
