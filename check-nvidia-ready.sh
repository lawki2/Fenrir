#!/usr/bin/env bash
# CachyOS sometimes bumps nvidia-utils ahead of the matching nvidia-open kernel
# module - run before ./buildiso.sh.
set -eo pipefail

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -sfL "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos.db" -o "$tmp/db"
bsdtar -xf "$tmp/db" -C "$tmp"

utils="$(basename "$(ls -d "$tmp"/nvidia-utils-* | head -1)")"
utils="${utils#nvidia-utils-}"; utils="${utils%-*}"
echo "[cachyos] nvidia-utils: $utils"

ok=0
for p in linux-cachyos-nvidia-open; do
    d="$(ls -d "$tmp/$p"-* 2>/dev/null | head -1)" || continue
    need="$(awk '/^%DEPENDS%/{f=1;next}/^%/{f=0}f' "$d/desc" | grep -m1 '^nvidia-utils=')"
    need="${need#nvidia-utils=}"
    if [[ "$need" == "$utils" ]]; then
        echo "  OK       $(basename "$d") -> $need"
    else
        echo "  MISMATCH $(basename "$d") -> $need"; ok=1
    fi
done

(( ok )) && { echo "Still broken upstream - don't build yet."; exit 1; }
echo "In sync - safe to run ./buildiso.sh"
