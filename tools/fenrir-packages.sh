#!/usr/bin/env bash
# Fenrir's locally built packages, their build inputs and staleness checks. Sourced by
# build-local-repo.sh, buildiso.sh and publish-fenrir-repo.sh with $src_dir set.

fenrir_repo_dir="${src_dir}/local-repo"
fenrir_chroot_dir="${src_dir}/aur-build/chroot"
# The invoking user's home, also under sudo (buildiso.sh runs as root).
fenrir_user_home="$(getent passwd "${SUDO_USER:-$(id -un)}" | cut -d: -f6)"

# Build order. The chroot installs depends from local-repo, so caelestia-cli -> fenrir-welcome
# -> fenrir-keyring -> fenrir-settings -> caelestia-shell must stay in this order.
fenrir_build_order=(
    qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf qt6-m3shapes-git sweet-cursors-git
    caelestia-cli fenrir-welcome fenrir-keyring fenrir-settings caelestia-shell
    caelestia-meta fenrir-installer fenrir-splash
)

# PKGBUILD directories, relative to the repo root or absolute; everything else comes from the AUR.
# caelestia-meta isn't on the AUR: ~/caelestia is cloned once and never auto-pulled.
declare -gA fenrir_pkg_src=(
    [fenrir-welcome]=fenrir-welcome
    [fenrir-keyring]=fenrir-keyring
    [fenrir-settings]=fenrir-settings
    [fenrir-installer]=fenrir-installer
    [fenrir-splash]=fenrir-splash
    [caelestia-meta]="$fenrir_user_home/caelestia"
)

# Known-good commits, so the overlay files only meet upstream changes on a deliberate bump.
declare -gA fenrir_aur_pins=(
    [caelestia-cli]="58f0b55e2231476b01ddfb829d20b6fb474b1f1a"   # 1.1.2
    [caelestia-shell]="e43db3eb47e45935d9c71b7f1b41817c85aa2bcb" # 2.4.0
)

# Files the splice_* functions below copy into a package's build dir.
declare -gA fenrir_splice_inputs=(
    [caelestia-shell]="fenrir-nexus-patches assets/wallpaper.webp"
    [caelestia-cli]="assets/schemes/fenrir"
    [fenrir-keyring]="archiso/airootfs/etc/pacman.d/fenrir-signing-key.asc"
)

# Bump to force a rebuild when none of the inputs changed.
declare -gA fenrir_rebuild=(
    [caelestia-cli]=1
    [caelestia-shell]=11
)

# Built against these chroot packages' ABI (qtengine uses Qt's private API), so a new version rebuilds them.
declare -gA fenrir_abi_deps=(
    [qtengine]=qt6-base
    [qt6-m3shapes-git]=qt6-base
    [caelestia-shell]=qt6-base
)

# Fenrir's own packages whose pkgver is the build time; AUR packages get a <n>.<time> pkgrel instead.
fenrir_stamped_pkgs=(fenrir-keyring fenrir-settings fenrir-splash fenrir-welcome)

# Fails unless sed changed the file and left $want in it: an unmatched sed is otherwise silent.
splice_sed() {
    local file="$1" want="$2" before
    shift 2
    before="$(sha256sum < "$file")"
    sed -i "$@" "$file" || return 1
    if [[ "$(sha256sum < "$file")" == "$before" ]] || ! grep -qF -- "$want" "$file"; then
        echo "==> Splice did not apply to $file (expected: $want) - update it for the new PKGBUILD." >&2
        return 1
    fi
}

# Every rebuild must reach -Syu as an update, and publish refuses an equal version.
stamp_version() {
    local pkg="$1" file="$2/PKGBUILD" now="$3"
    if [[ " ${fenrir_stamped_pkgs[*]} " == *" $pkg "* ]]; then
        splice_sed "$file" "pkgver=${now:0:4}.${now:4:2}.${now:6:2}.${now:8:4}" \
            "s/^pkgver=.*/pkgver=${now:0:4}.${now:4:2}.${now:6:2}.${now:8:4}/" || return 1
    elif [[ -z "${fenrir_pkg_src[$pkg]:-}" ]]; then
        splice_sed "$file" ".${now}" -E "s/^pkgrel=([0-9]+)(\.[0-9]+)*\$/pkgrel=\1.${now}/" || return 1
    fi
}

# The key can't be in source=(): makepkg takes a .asc source for a signature.
splice_fenrir_keyring() {
    cp "$src_dir/archiso/airootfs/etc/pacman.d/fenrir-signing-key.asc" "$1/" || return 1
}

splice_caelestia_cli() {
    local dir="$1"
    # Copied *into* schemes/: a glob only expands over paths that exist, so it can't end at fenrir/.
    cp -r "$src_dir/assets/schemes/fenrir" "$dir/fenrir" || return 1
    splice_sed "$dir/PKGBUILD" 'cp -r "$startdir/fenrir" "$pkgdir"/usr/lib/python*/site-packages/caelestia/data/schemes/' \
        '/python -m installer --destdir/a\    cp -r "$startdir/fenrir" "$pkgdir"/usr/lib/python*/site-packages/caelestia/data/schemes/' || return 1
}

splice_caelestia_shell() {
    local dir="$1" file="$1/PKGBUILD"
    # CachyOS's quickshell-git predates the DefaultEnv pragma shell.qml needs.
    splice_sed "$file" "'quickshell'" "s/'quickshell-git'/'quickshell'/" || return 1
    if grep -q 'quickshell-git' "$file"; then
        echo "==> $file still names quickshell-git - update the quickshell splice." >&2
        return 1
    fi
    # Shown as the shell's distributor by `caelestia --version`.
    splice_sed "$file" '-DDISTRIBUTOR="Fenrir"' 's/-DDISTRIBUTOR="[^"]*"/-DDISTRIBUTOR="Fenrir"/' || return 1
    # Pulls fenrir-settings into existing installs, which only -Syu what they already have.
    splice_sed "$file" "    'fenrir-settings'" "s/^depends=($/depends=(\n    'fenrir-settings'/" || return 1
    # Wallpapers.qml falls back to this packaged path; pacstrap would clobber an airootfs copy.
    cp "$src_dir/assets/wallpaper.webp" "$dir/fenrir-wallpaper.webp" || return 1
    splice_sed "$file" 'install -Dm644 "$startdir/fenrir-wallpaper.webp" "$pkgdir/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"' \
        '/DESTDIR="\$pkgdir" cmake --install build/a\    install -Dm644 "$startdir/fenrir-wallpaper.webp" "$pkgdir/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"' || return 1
    cp -r "$src_dir/fenrir-nexus-patches/etc" "$dir/fenrir-nexus-etc" || return 1
    splice_sed "$file" 'cp -rv "$startdir/fenrir-nexus-etc/." "$pkgdir/etc/"' \
        '/DESTDIR="\$pkgdir" cmake --install build/a\    cp -rv "$startdir/fenrir-nexus-etc/." "$pkgdir/etc/"' || return 1
}

# Every package file in dir $1 whose pkgname is exactly $2 (so not $2-debug).
pkg_files() {
    local f name
    for f in "$1/$2"-*.pkg.tar.zst; do
        [[ -e "$f" ]] || continue
        name="${f##*/}"
        [[ "${name%-*-*-*.pkg.tar.zst}" == "$2" ]] && printf '%s\n' "$f"
    done
    return 0
}

# Newest by mtime: glob order would put 2.3.0 ahead of 2.4.0.
pkg_file() {
    pkg_files "$1" "$2" | xargs -r -d '\n' ls -t | head -1
}

# The package's input paths: its PKGBUILD dir if local, plus the Fenrir files spliced into it.
pkg_input_paths() {
    local p
    for p in ${fenrir_pkg_src[$1]:-} ${fenrir_splice_inputs[$1]:-}; do
        if [[ "$p" == /* ]]; then printf '%s\n' "$p"; else printf '%s\n' "$src_dir/$p"; fi
    done
}

# One line per file: kind, exec bit, path and content (links: target), so renames and deletions count.
hash_tree() {
    local path="$1" f rel
    if [[ ! -e "$path" ]]; then
        echo "==> Build input ${path#"$src_dir"/} is missing." >&2
        return 1
    fi
    printf 'input %s\n' "${path#"$src_dir"/}"
    while IFS= read -r -d '' f; do
        rel="${f#"$path"}"
        if [[ -L "$f" ]]; then
            printf 'l %s %s\n' "$rel" "$(readlink "$f")"
        else
            printf 'f %s %s %s\n' "$([[ -x "$f" ]] && echo x || echo -)" "$rel" "$(sha256sum < "$f" | cut -c1-64)"
        fi
    done < <(find "$path" \( -name .git -o -name __pycache__ \) -prune -o \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
}

# The compiler flags and options the chroot's makepkg builds with.
chroot_build_flags() {
    local conf="$fenrir_chroot_dir/root/etc/makepkg.conf"
    if [[ ! -r "$conf" ]]; then
        echo "==> No build chroot at $fenrir_chroot_dir - run build-local-repo.sh first." >&2
        return 1
    fi
    (
        set +eu
        source "$conf"
        for f in "$conf.d"/*.conf; do [[ -r "$f" ]] && source "$f"; done
        printf 'CFLAGS=%s\nCXXFLAGS=%s\nLDFLAGS=%s\nLTOFLAGS=%s\nRUSTFLAGS=%s\nFFLAGS=%s\nOPTIONS=%s\n' \
            "$CFLAGS" "$CXXFLAGS" "$LDFLAGS" "$LTOFLAGS" "$RUSTFLAGS" "$FFLAGS" "${OPTIONS[*]}"
    )
}

# Set by fresh_repo_dbs, so buildiso and publish compare against today's repos, not the chroot's last sync.
fenrir_fresh_dbpath=""

# A private copy per run, so a stale lock or a root-owned leftover can't block it; the caller removes it.
fresh_repo_dbs() {
    local fake=(fakeroot --)
    (( EUID == 0 )) && fake=()
    fenrir_fresh_dbpath="$(mktemp -d)"
    mkdir -p "$fenrir_fresh_dbpath/local"
    "${fake[@]}" pacman -Sy --config "$src_dir/archiso/pacman.conf" --dbpath "$fenrir_fresh_dbpath" --logfile /dev/null >/dev/null
}

# The version of $1 the chroot would install, from its synced repo databases.
chroot_repo_version() {
    local root="$fenrir_chroot_dir/root"
    if [[ -n "$fenrir_fresh_dbpath" ]]; then
        pacman --config "$src_dir/archiso/pacman.conf" --dbpath "$fenrir_fresh_dbpath" -Sddp --print-format '%v' "$1"
    else
        pacman --config "$root/etc/pacman.conf" --dbpath "$root/var/lib/pacman" -Sddp --print-format '%v' "$1"
    fi
}

pkg_key_material() {
    local pkg="$1" dep ver input
    printf 'pkg=%s\nrebuild=%s\npin=%s\n' "$pkg" "${fenrir_rebuild[$pkg]:-0}" "${fenrir_aur_pins[$pkg]:-}"
    declare -f "splice_${pkg//-/_}" || true
    chroot_build_flags || return 1
    for dep in ${fenrir_abi_deps[$pkg]:-}; do
        ver="$(chroot_repo_version "$dep")" || return 1
        printf '%s=%s\n' "$dep" "$ver"
    done
    while IFS= read -r input; do
        hash_tree "$input" || return 1
    done < <(pkg_input_paths "$pkg")
}

pkg_key() {
    local material
    material="$(pkg_key_material "$1")" || return 1
    printf '%s\n' "$material" | sha256sum | cut -c1-64
}

pkg_marker() {
    printf '%s/%s.inputs\n' "$fenrir_repo_dir" "$1"
}

# Records which inputs produced the package file $3, next to it in local-repo.
write_pkg_marker() {
    printf 'key=%s\nfile=%s\nsha256=%s\n' "$2" "${3##*/}" "$(sha256sum < "$3" | cut -c1-64)" > "$(pkg_marker "$1")"
}

# Exit 0 if local-repo's $1 was built from its current inputs, 1 (printing why) if not, 2 on error.
pkg_check_current() {
    local pkg="$1" file marker key
    file="$(pkg_file "$fenrir_repo_dir" "$pkg")"
    if [[ -z "$file" ]]; then
        echo "$pkg is not built"
        return 1
    fi
    marker="$(pkg_marker "$pkg")"
    if [[ ! -r "$marker" ]]; then
        echo "${file##*/} has no recorded inputs"
        return 1
    fi
    key="$(pkg_key "$pkg")" || return 2
    if [[ "$(sed -n 's/^key=//p' "$marker")" != "$key" ]]; then
        echo "$pkg's inputs changed since ${file##*/} was built"
        return 1
    fi
    if [[ "$(sed -n 's/^file=//p' "$marker")" != "${file##*/}" ||
          "$(sed -n 's/^sha256=//p' "$marker")" != "$(sha256sum < "$file" | cut -c1-64)" ]]; then
        echo "${file##*/} is not the package its inputs were recorded for"
        return 1
    fi
}

# "name version sha256" for every package in a repo database.
served_packages() {
    bsdtar -xOf "$1" | awk '
        /^%[A-Z0-9]+%$/ { key = $0; next }
        !NF { key = ""; next }
        key == "%NAME%" { name = $0 }
        key == "%VERSION%" { ver = $0 }
        key == "%SHA256SUM%" { print name, ver, $0 }'
}

# Prints new, newer or same for package file $2 of $1 against the served list $3; refuses (exit 1)
# an older version, or an equal one with different content, since clients would never fetch it.
publish_verdict() {
    local pkg="$1" file="$2" served="$3" base ver name s_ver s_sum
    base="${file##*/}"
    ver="${base#"$pkg"-}"
    ver="${ver%-*.pkg.tar.zst}"
    read -r name s_ver s_sum < <(awk -v n="$pkg" '$1 == n' "$served") || true
    if [[ -z "${s_ver:-}" ]]; then
        echo new
        return 0
    fi
    case "$(vercmp "$ver" "$s_ver")" in
        1) echo newer ;;
        0)
            if [[ "$(sha256sum < "$file" | cut -c1-64)" == "$s_sum" ]]; then
                echo same
            else
                echo "$base has the version gh-pages already serves, with different content"
                return 1
            fi
            ;;
        *)
            echo "$base is older than the served $pkg $s_ver"
            return 1
            ;;
    esac
}
