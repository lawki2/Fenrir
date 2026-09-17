#!/usr/bin/env bash
# Signs caelestia-cli/caelestia-shell out of local-repo/ (built by
# build-local-repo.sh) and publishes them + a signed repo database to the
# gh-pages branch of https://github.com/lawki2/Fenrir, which GitHub Pages
# serves as the [fenrir] repo installed systems point at (see
# archiso/airootfs/etc/pacman.d/fenrir-mirrorlist and
# fenrir-installer/lib/backend.py's configure_fenrir_repo()).
#
# Run manually, after build-local-repo.sh has produced fresh packages,
# whenever you actually want to publish a new caelestia-shell/-cli build.
# Unlike build-local-repo.sh this pushes to a public branch and needs the
# Fenrir project signing key - deliberately not wired into
# build-local-repo.sh's or buildiso.sh's automatic flow.
# Not -u: util.sh's load_vars() uses indirect expansion (${!var}) on
# makepkg.conf variables that are typically never set at all (SRCDEST,
# PACKAGER, etc.) - harmless under normal bash (expands empty), but fatal
# under nounset. buildiso.sh, which sources the same util.sh, avoids this
# the same way: plain set -e, no -u.
set -eo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -r ${src_dir}/util-msg.sh ]] && source ${src_dir}/util-msg.sh
import ${src_dir}/util.sh

# Project-local, gitignored signing setup (never the maintainer's personal
# ~/.gnupg) - see secrets/ in the one-time setup checklist. Exporting
# GPGKEY/GNUPGHOME here before sign_with_key()'s own load_vars() runs
# means they take precedence over anything in ~/.makepkg.conf, per
# load_vars()'s "only set if not already set" logic.
secrets_dir="${src_dir}/secrets"
[[ -f "${secrets_dir}/publish.env" ]] && source "${secrets_dir}/publish.env"

repo_dir="${src_dir}/local-repo"
publish_dir="${src_dir}/publish-repo"
arch="x86_64"
repo_name="fenrir"
gh_pages_url="https://github.com/lawki2/Fenrir.git"
gh_pages_branch="gh-pages"

# The Caelestia stack plus its AUR-only deps - all tiny, and without them an
# installed system can't resolve a new dep (2.4.0 added qt6-m3shapes-git).
# Excludes fenrir-installer (live-only) and zen-browser-bin (126MB, not a dep).
published_pkgs=(
    caelestia-cli caelestia-shell
    qt6-m3shapes-git qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf
)

load_vars "$HOME/.makepkg.conf" || true
load_vars /etc/makepkg.conf
[[ -n "${GPGKEY:-}" ]] || die "GPGKEY is not set (see secrets/publish.env) - refusing to publish an unsigned [fenrir] repo."

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
# GitHub Pages runs Jekyll by default, which ignores/mangles paths
# starting with an underscore and can interfere with serving a raw binary
# tree - .nojekyll disables that. Only matters on first publish.
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
