#!/usr/bin/env bash
# Signs packages from local-repo/ and publishes them to the gh-pages branch that
# serves the [fenrir] repo. Manual on purpose: it pushes publicly and needs the key.

# Not -u: util.sh's load_vars() expands makepkg.conf vars that are usually unset.
set -eo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -r ${src_dir}/util-msg.sh ]] && source ${src_dir}/util-msg.sh
import ${src_dir}/util.sh
import ${src_dir}/tools/fenrir-packages.sh

# The project's own gitignored keyring, never ~/.gnupg. Exported before load_vars()
# runs, so it wins over ~/.makepkg.conf.
secrets_dir="${src_dir}/secrets"
[[ -f "${secrets_dir}/publish.env" ]] && source "${secrets_dir}/publish.env"

repo_dir="$fenrir_repo_dir"
publish_dir="${src_dir}/publish-repo"
arch="x86_64"
repo_name="fenrir"
gh_pages_url="https://github.com/lawki2/Fenrir.git"
gh_pages_branch="gh-pages"

# The Caelestia stack plus its AUR-only deps, so an update can resolve a new one, and
# Fenrir's own installed packages. Not fenrir-installer, which only runs on the live ISO.
published_pkgs=(
    caelestia-cli caelestia-shell fenrir-keyring fenrir-settings fenrir-splash fenrir-welcome
    qt6-m3shapes-git qtengine app2unit python-materialyoucolor libcava ttf-rubik-vf sweet-cursors-git
)

load_vars "$HOME/.makepkg.conf" || true
load_vars /etc/makepkg.conf
[[ -n "${GPGKEY:-}" ]] || die "GPGKEY is not set (see secrets/publish.env) - refusing to publish an unsigned [fenrir] repo."

# Publishing only copies what build-local-repo.sh produced, so it must match its current inputs.
fresh_repo_dbs || die "Couldn't sync the repo databases to check the packages against."
for pkg in "${published_pkgs[@]}"; do
    reason="$(pkg_check_current "$pkg")" || die "%s - run build-local-repo.sh first." "${reason:-$pkg could not be checked}"
done
rm -rf "$fenrir_fresh_dbpath"

rm -rf "$publish_dir"
mkdir -p "$publish_dir/$arch"

# What gh-pages serves now; the push below is leased against this exact commit.
served_list="$publish_dir/served.txt"
: > "$served_list"
served_commit=""
if git ls-remote --exit-code --heads "$gh_pages_url" "$gh_pages_branch" >/dev/null; then
    served_repo="$publish_dir/served.git"
    git clone --quiet --bare --depth 1 --filter=blob:none --branch "$gh_pages_branch" "$gh_pages_url" "$served_repo"
    served_commit="$(git -C "$served_repo" rev-parse HEAD)"
    git -C "$served_repo" show "HEAD:$arch/$repo_name.db.tar.gz" > "$publish_dir/served.db.tar.gz"
    served_packages "$publish_dir/served.db.tar.gz" > "$served_list"
elif [[ $? -eq 2 ]]; then
    warning "%s has no %s branch yet, creating it." "$gh_pages_url" "$gh_pages_branch"
else
    die "Could not read %s from %s." "$gh_pages_branch" "$gh_pages_url"
fi

changed=false
[[ "$(wc -l < "$served_list")" -eq "${#published_pkgs[@]}" ]] || changed=true
for pkg in "${published_pkgs[@]}"; do
    file="$(pkg_file "$repo_dir" "$pkg")"
    verdict="$(publish_verdict "$pkg" "$file" "$served_list")" ||
        die "%s - delete it from local-repo/ and run build-local-repo.sh for a new version." "$verdict"
    msg2 "%s: %s" "${file##*/}" "$verdict"
    [[ "$verdict" == same ]] || changed=true
    cp "$file" "$publish_dir/$arch/"
done
if ! $changed; then
    msg "gh-pages already serves exactly these packages, nothing to publish."
    exit 0
fi

for file in "$publish_dir/$arch"/*.pkg.tar.zst; do
    sign_with_key "$file"
done
repo-add -s -k "$GPGKEY" "$publish_dir/$arch/${repo_name}.db.tar.gz" "$publish_dir/$arch"/*.pkg.tar.zst

msg "Publishing to %s (%s)" "$gh_pages_url" "$gh_pages_branch"
# A single orphan commit replaces the branch, so old package blobs never pile up in every clone.
site_dir="$publish_dir/site"
git init --quiet -b "$gh_pages_branch" "$site_dir"
# Stop GitHub Pages running Jekyll over a raw binary tree.
touch "$site_dir/.nojekyll"
cp -r "$publish_dir/$arch" "$site_dir/$arch"
git -C "$site_dir" add ".nojekyll" "$arch"
git -C "$site_dir" commit --quiet -m "Publish ${published_pkgs[*]} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git -C "$site_dir" push --force-with-lease="$gh_pages_branch:$served_commit" \
    "$gh_pages_url" "$gh_pages_branch:refs/heads/$gh_pages_branch"
