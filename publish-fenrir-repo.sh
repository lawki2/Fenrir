#!/usr/bin/env bash
# Signs packages from local-repo/ and publishes them to the gh-pages branch that
# serves the [fenrir] repo. Manual on purpose: it pushes publicly and needs the key.

# Not -u: util.sh's load_vars() expands makepkg.conf vars that are usually unset.
set -eo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -r ${src_dir}/util-msg.sh ]] && source ${src_dir}/util-msg.sh
import ${src_dir}/util.sh

# The project's own gitignored keyring, never ~/.gnupg. Exported before load_vars()
# runs, so it wins over ~/.makepkg.conf.
secrets_dir="${src_dir}/secrets"
[[ -f "${secrets_dir}/publish.env" ]] && source "${secrets_dir}/publish.env"

repo_dir="${src_dir}/local-repo"
publish_dir="${src_dir}/publish-repo"
arch="x86_64"
repo_name="fenrir"
gh_pages_url="https://github.com/lawki2/Fenrir.git"
gh_pages_branch="gh-pages"

# The Caelestia stack plus its AUR-only deps, so an update can resolve a new one, and
# Fenrir's own installed packages. Not fenrir-installer, which only runs on the live ISO.
published_pkgs=(
    caelestia-cli caelestia-shell fenrir-settings fenrir-splash fenrir-welcome
    qt6-m3shapes-git qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf
)

load_vars "$HOME/.makepkg.conf" || true
load_vars /etc/makepkg.conf
[[ -n "${GPGKEY:-}" ]] || die "GPGKEY is not set (see secrets/publish.env) - refusing to publish an unsigned [fenrir] repo."

# Publishing only copies what build-local-repo.sh already produced, so a
# newer overlay than the built package means shipping stale content silently.
shell_pkg="$(find "$repo_dir" -maxdepth 1 -name "caelestia-shell-*.pkg.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
if [[ -n "$shell_pkg" ]] && [[ -n "$(find "$src_dir/fenrir-nexus-patches" -type f -newer "$shell_pkg" 2>/dev/null)" ]]; then
    die "fenrir-nexus-patches/ is newer than %s - run build-local-repo.sh first (and bump fenrir_rebuild if the version is unchanged)." "$(basename "$shell_pkg")"
fi

rm -rf "$publish_dir"
mkdir -p "$publish_dir/$arch"

for pkg in "${published_pkgs[@]}"; do
    # Newest by mtime: a glob would sort 2.3.0 ahead of 2.4.0.
    pkg_file="$(find "$repo_dir" -maxdepth 1 -name "${pkg}-*.pkg.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
    [[ -n "$pkg_file" ]] || die "%s not found in %s - run build-local-repo.sh first." "$pkg" "$repo_dir"
    cp "$pkg_file" "$publish_dir/$arch/"
    sign_with_key "$publish_dir/$arch/$(basename "$pkg_file")"
done

repo-add -s -k "$GPGKEY" "$publish_dir/$arch/${repo_name}.db.tar.gz" "$publish_dir/$arch"/*.pkg.tar.zst

msg "Publishing to %s (%s)" "$gh_pages_url" "$gh_pages_branch"
clone_dir="$publish_dir/gh-pages-clone"
rm -rf "$clone_dir"
if ! git clone --branch "$gh_pages_branch" --single-branch "$gh_pages_url" "$clone_dir" 2>/dev/null; then
    # git init alone doesn't configure a remote, unlike git clone above -
    # add it explicitly or the push at the bottom has nowhere to go.
    git init "$clone_dir"
    git -C "$clone_dir" remote add origin "$gh_pages_url"
    git -C "$clone_dir" checkout --orphan "$gh_pages_branch"
fi
# Stop GitHub Pages running Jekyll over a raw binary tree.
touch "$clone_dir/.nojekyll"
rm -rf "${clone_dir:?}/$arch"
cp -r "$publish_dir/$arch" "$clone_dir/$arch"

git -C "$clone_dir" add ".nojekyll" "$arch"
if git -C "$clone_dir" diff --cached --quiet; then
    msg "Nothing changed, nothing to publish."
else
    git -C "$clone_dir" commit -m "Publish ${published_pkgs[*]} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    git -C "$clone_dir" push origin "$gh_pages_branch"
fi
