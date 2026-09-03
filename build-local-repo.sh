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

# Pin to known-good commits — an unpinned clone once silently broke
# fenrir-nexus-patches/Toggles.qml on a version bump. Bump deliberately.
declare -A pinned_aur_commits=(
    [caelestia-cli]="58f0b55e2231476b01ddfb829d20b6fb474b1f1a"   # 1.1.2
    [caelestia-shell]="0b4bd59c6043fa838c62d00f6fa9457f788c263f" # 2.3.0
)

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
    local existing
    existing="$(compgen -G "$repo_dir/${pkg}-*.pkg.tar.zst" | head -1)" || true

    if [[ -n "$existing" ]]; then
        if [[ "$pkg" == "caelestia-shell" ]]; then
            # caelestia-shell splices in fenrir-nexus-patches/ and the
            # wallpaper at build time, so check those for staleness too.
            if [[ -z "$(find "$src_dir/fenrir-nexus-patches" "$src_dir/assets/wallpaper.webp" -type f -newer "$existing" 2>/dev/null)" ]]; then
                echo "==> $pkg already built and up to date, skipping"
                return
            fi
            echo "==> $pkg's Nexus overlay or wallpaper changed since last build, rebuilding"
            rm -f "$repo_dir/${pkg}"-*.pkg.tar.zst
        elif [[ "$src" == "aur" ]]; then
            echo "==> $pkg already built, skipping (delete $repo_dir/${pkg}-*.pkg.tar.zst to rebuild)"
            return
        else
            # Local packages have a real source tree to diff against;
            # a stale binary shipped silently three times before this check.
            if [[ -z "$(find "$src" -type f -newer "$existing" 2>/dev/null)" ]]; then
                echo "==> $pkg already built and up to date, skipping"
                return
            fi
            echo "==> $pkg source changed since last build, rebuilding"
            rm -f "$repo_dir/${pkg}"-*.pkg.tar.zst
        fi
    fi

    rm -rf "$build_root"
    if [[ "$src" == "aur" ]]; then
        if [[ -n "${pinned_aur_commits[$pkg]:-}" ]]; then
            # Pinned packages need full history to check out an arbitrary
            # older commit - these repos are tiny (a PKGBUILD + a patch or
            # two), so the extra clone cost is negligible.
            git clone "https://aur.archlinux.org/${pkg}.git" "$build_root"
            git -C "$build_root" checkout "${pinned_aur_commits[$pkg]}"
        else
            git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$build_root"
        fi
    else
        mkdir -p "$build_root"
        cp -r "$src"/* "$build_root"/
    fi

    if [[ "$pkg" == "caelestia-shell" ]]; then
        # CachyOS's quickshell-git is a stale snapshot predating "DefaultEnv"
        # pragma support that shell.qml requires; build against quickshell instead.
        sed -i "s/'quickshell-git'/'quickshell'/" "$build_root/PKGBUILD"

        # sed's `a` is a silent no-op if this anchor line ever changes,
        # which would ship a broken ISO with zero build-log error.
        if ! grep -qF 'DESTDIR="$pkgdir" cmake --install build' "$build_root/PKGBUILD"; then
            echo "==> caelestia-shell's PKGBUILD no longer has the expected" \
                "'DESTDIR=\"\$pkgdir\" cmake --install build' line - the wallpaper" \
                "and Nexus overlay injection below needs updating for the new" \
                "PKGBUILD shape before this pin can be trusted." >&2
            exit 1
        fi

        # Wallpapers.qml's fallback is hardcoded to this packaged path; an
        # airootfs overlay can't win here since pacstrap runs after and clobbers it.
        cp "$src_dir/assets/wallpaper.webp" "$build_root/fenrir-wallpaper.webp"
        sed -i '/DESTDIR="\$pkgdir" cmake --install build/a\    install -Dm644 "$startdir/fenrir-wallpaper.webp" "$pkgdir/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"' \
            "$build_root/PKGBUILD"

        # Overlay fenrir-nexus-patches/ onto the cmake-installed tree,
        # same anchor point as the wallpaper install above.
        cp -r "$src_dir/fenrir-nexus-patches/etc" "$build_root/fenrir-nexus-etc"
        sed -i '/DESTDIR="\$pkgdir" cmake --install build/a\    cp -rv "$startdir/fenrir-nexus-etc/." "$pkgdir/etc/"' \
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

# Not on AUR; built from ~/caelestia, cloned once and never auto-pulled —
# same pin-deliberately policy as pinned_aur_commits above.
if [[ ! -d "$HOME/caelestia" ]]; then
    git clone https://github.com/caelestia-dots/caelestia.git "$HOME/caelestia"
fi
build_one "caelestia-meta" "$HOME/caelestia"

# Fenrir's own package, not on AUR; its PKGBUILD lives in this repo.
build_one "fenrir-installer" "$src_dir/fenrir-installer"

echo "==> Done. Built packages are in $repo_dir"
ls -1 "$repo_dir"/*.pkg.tar.zst
