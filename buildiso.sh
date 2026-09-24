#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

set -e
src_dir=$(pwd)
[[ -r ${src_dir}/util-msg.sh ]] && source ${src_dir}/util-msg.sh
import ${src_dir}/util.sh

# setting of the general parameters
work_dir="${src_dir}/build"
outFolder="${src_dir}/out"

build_list_iso="fenrir"
clean_first=true
verbose=false
build_in_ram=false
remove_build_dir=false

usage() {
    echo "Usage: ${0##*/} [options]"
    echo '    -c                 Disable clean work dir'
    echo '    -r                 Enable building in RAM on systems with more than 23GB RAM'
    echo '    -w                 Remove build directory (not the ISO) after ISO file is built'
    echo "    -p <profile>       Buildset or profile [default: ${build_list_iso}]"
    echo '    -v                 Verbose output to log file, show profile detail (-q)'
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

orig_argv=("$@")

opts='p:cvhrw'

while getopts "${opts}" arg; do
    case "${arg}" in
        c) clean_first=false ;;
        p) build_list_iso="$OPTARG" ;;
        r) build_in_ram=true ;;
        w) remove_build_dir=true ;;
        v) verbose=true ;;
        h|?) usage 0 ;;
        *) echo "invalid argument '${arg}'"; usage 1 ;;
    esac
done

shift $(($OPTIND - 1))

timer_start=$(get_timer)

#check_root "$0" "${orig_argv[@]}"

# Build ISO in RAM if RAM amount is greater than 23GB. This would speed up build process and extend disk lifetime 
if [[ "$build_in_ram" == "true" ]] && [[ $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}') -gt 23 ]]; then
    work_dir="$(mktemp -d --suffix="-cachyos-iso")"
fi

prepare_dir "${work_dir}"

import ${src_dir}/util-iso.sh
import ${src_dir}/util-iso-mount.sh

check_requirements

# Refuse to assemble an ISO from a package older than its source tree.
for pkg_dir in fenrir-installer fenrir-splash fenrir-settings fenrir-welcome; do
    built="$(find "${src_dir}/local-repo" -maxdepth 1 -name "${pkg_dir}-*.pkg.tar.zst" \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
    if [[ -z "$built" ]]; then
        die "No %s package in local-repo/ - run build-local-repo.sh first." "$pkg_dir"
    fi
    if [[ -n "$(find "${src_dir}/${pkg_dir}" -type f -newer "$built" 2>/dev/null)" ]]; then
        die "%s/ is newer than %s - run build-local-repo.sh first." "$pkg_dir" "$(basename "$built")"
    fi
done

for sig in TERM HUP QUIT; do
    trap "trap_exit $sig \"$(gettext "%s signal caught. Exiting...")\" \"$sig\"" "$sig"
done
trap 'trap_exit INT "$(gettext "Aborted by user! Exiting...")"' INT
trap 'trap_exit USR1 "$(gettext "An unknown error has occurred. Exiting...")"' ERR
trap 'trap_exit EXIT "$(gettext "An unknown error has occurred. Exiting...")"' EXIT

run_build "${build_list_iso}"
