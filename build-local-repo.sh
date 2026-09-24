#!/usr/bin/env bash
# Builds the AUR and Fenrir packages into local-repo/, so the ISO build never
# needs AUR access. Run before ./buildiso.sh.
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work_dir="${src_dir}/aur-build"
repo_dir="${src_dir}/local-repo"
chroot_dir="${work_dir}/chroot"
repo_name="fenrir-local"

mkdir -p "$work_dir" "$repo_dir"

# Packages with no interdependencies among themselves, build first.
# zen-browser-bin is not here: [cachyos] carries it, and the ISO takes it from there.
independent_aur_pkgs=(qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf qt6-m3shapes-git)

# Pin to known-good commits — an unpinned clone once silently broke
# fenrir-nexus-patches/Toggles.qml on a version bump. Bump deliberately.
declare -A pinned_aur_commits=(
    [caelestia-cli]="58f0b55e2231476b01ddfb829d20b6fb474b1f1a"   # 1.1.2
    [caelestia-shell]="e43db3eb47e45935d9c71b7f1b41817c85aa2bcb" # 2.4.0
)

# Fenrir files spliced into these AUR packages at build time; a change rebuilds them.
declare -A spliced_inputs=(
    [caelestia-shell]="fenrir-nexus-patches assets/wallpaper.webp"
    [caelestia-cli]="assets/schemes/fenrir"
)

# Bump to force a rebuild against updated deps at an unchanged upstream version. For the
# spliced packages the version comes from the build time instead, see build_one.
declare -A fenrir_rebuild=(
    [caelestia-cli]=1
    [caelestia-shell]=11
)

# Fenrir's own packages whose pkgver is the build time, so each rebuild reaches -Syu as an update.
stamped_pkgs=(fenrir-settings fenrir-splash fenrir-welcome)

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
    # Newest by mtime: a glob would sort 2.3.0 ahead of 2.4.0.
    existing="$(find "$repo_dir" -maxdepth 1 -name "${pkg}-*.pkg.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"

    local rebuild="${fenrir_rebuild[$pkg]:-0}"
    local marker="$work_dir/.rebuild-${pkg}"
    if [[ -n "$existing" && "$(cat "$marker" 2>/dev/null || echo 0)" != "$rebuild" ]]; then
        echo "==> $pkg rebuild counter is now $rebuild, forcing rebuild"
        rm -f "$repo_dir/${pkg}"-*.pkg.tar.zst
        existing=""
    fi

    if [[ -n "$existing" ]]; then
        # Rebuild only when something that goes into the package is newer than it.
        local -a inputs=()
        if [[ "$src" != "aur" ]]; then
            inputs=("$src")
        elif [[ -n "${spliced_inputs[$pkg]:-}" ]]; then
            for rel in ${spliced_inputs[$pkg]}; do inputs+=("$src_dir/$rel"); done
        else
            echo "==> $pkg already built, skipping (delete $repo_dir/${pkg}-*.pkg.tar.zst to rebuild)"
            return
        fi
        if [[ -z "$(find "${inputs[@]}" -type f -newer "$existing" 2>/dev/null)" ]]; then
            echo "==> $pkg already built and up to date, skipping"
            return
        fi
        echo "==> $pkg inputs changed since last build, rebuilding"
        rm -f "$repo_dir/${pkg}"-*.pkg.tar.zst
    fi

    rm -rf "$build_root"
    if [[ "$src" == "aur" ]]; then
        if [[ -n "${pinned_aur_commits[$pkg]:-}" ]]; then
            # A pinned commit needs full history; these repos are a few KB.
            git clone "https://aur.archlinux.org/${pkg}.git" "$build_root"
            git -C "$build_root" checkout "${pinned_aur_commits[$pkg]}"
        else
            git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$build_root"
        fi
    else
        mkdir -p "$build_root"
        cp -r "$src"/* "$build_root"/
    fi

    if [[ -n "${spliced_inputs[$pkg]:-}" ]]; then
        # Fenrir's changes don't move upstream's version, so every build gets a newer pkgrel of
        # its own; a hand-bumped counter let an ISO and a later publish share one version.
        sed -i -E "s/^pkgrel=([0-9]+)(\.[0-9]+)*\$/pkgrel=\1.$(date +%Y%m%d%H%M)/" "$build_root/PKGBUILD"
    elif (( rebuild > 0 )); then
        sed -i -E "s/^pkgrel=([0-9]+(\.[0-9]+)*)\$/pkgrel=\1.${rebuild}/" "$build_root/PKGBUILD"
    fi

    if [[ " ${stamped_pkgs[*]} " == *" $pkg "* ]]; then
        sed -i "s/^pkgver=.*/pkgver=$(date +%Y.%m.%d.%H%M)/" "$build_root/PKGBUILD"
    fi

    if [[ "$pkg" == "caelestia-cli" ]]; then
        # Ships the Fenrir scheme into the picker. Copied *into* schemes/: a glob only
        # expands over paths that exist, so it can't end at the new fenrir/ dir.
        if ! grep -qF 'python -m installer --destdir' "$build_root/PKGBUILD"; then
            echo "==> caelestia-cli's PKGBUILD no longer has the expected installer" \
                "line - the Fenrir scheme splice needs updating." >&2
            exit 1
        fi
        cp -r "$src_dir/assets/schemes/fenrir" "$build_root/fenrir"
        sed -i '/python -m installer --destdir/a\    cp -r "$startdir/fenrir" "$pkgdir"/usr/lib/python*/site-packages/caelestia/data/schemes/' \
            "$build_root/PKGBUILD"
    fi

    if [[ "$pkg" == "caelestia-shell" ]]; then
        # CachyOS's quickshell-git is a stale snapshot predating "DefaultEnv"
        # pragma support that shell.qml requires; build against quickshell instead.
        sed -i "s/'quickshell-git'/'quickshell'/" "$build_root/PKGBUILD"

        # Pulls fenrir-settings into existing installs, which only -Syu what they already have.
        if ! grep -q '^depends=($' "$build_root/PKGBUILD"; then
            echo "==> caelestia-shell's PKGBUILD no longer opens depends=( on its own line -" \
                "the fenrir-settings dependency splice needs updating." >&2
            exit 1
        fi
        sed -i "s/^depends=($/depends=(\n    'fenrir-settings'/" "$build_root/PKGBUILD"

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
    echo "$rebuild" > "$marker"
}

ensure_repo_db
ensure_chroot

for pkg in "${independent_aur_pkgs[@]}"; do
    build_one "$pkg" aur
done

# The chroot installs each package's depends before building it, so this order matters:
# fenrir-welcome needs caelestia-cli, fenrir-settings needs fenrir-welcome, caelestia-shell needs fenrir-settings.
build_one caelestia-cli aur
build_one "fenrir-welcome" "$src_dir/fenrir-welcome"
build_one "fenrir-settings" "$src_dir/fenrir-settings"
build_one caelestia-shell aur

# Not on AUR; built from ~/caelestia, cloned once and never auto-pulled —
# same pin-deliberately policy as pinned_aur_commits above.
if [[ ! -d "$HOME/caelestia" ]]; then
    git clone https://github.com/caelestia-dots/caelestia.git "$HOME/caelestia"
fi
build_one "caelestia-meta" "$HOME/caelestia"

# Fenrir's own packages, not on AUR; their PKGBUILDs live in this repo.
build_one "fenrir-installer" "$src_dir/fenrir-installer"
build_one "fenrir-splash" "$src_dir/fenrir-splash"

echo "==> Done. Built packages are in $repo_dir"
ls -1 "$repo_dir"/*.pkg.tar.zst
