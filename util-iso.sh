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

error_function() {
    if [[ -p $logpipe ]]; then
        rm "$logpipe"
    fi
    # first exit all subshells, then print the error
    if (( ! BASH_SUBSHELL )); then
        error "A failure occurred in %s()." "$1"
        plain "Aborting..."
    fi
    umount_fs
    umount_img
    exit 2
}

run_safe() {
    local restoretrap func="$1"
    set -e
    set -E
    restoretrap=$(trap -p ERR)
    trap 'error_function $func' ERR

    if ${verbose}; then
        run_log "$func"
    else
        "$func"
    fi

    eval $restoretrap
    set +E
    set +e
}

check_umount() {
    if mountpoint -q "$1"; then
        umount -l "$1"
    fi
}

trap_exit() {
    local sig=$1; shift
    error "$@"
    umount_fs
    trap -- "$sig"
    kill "-$sig" "$$"
}

generate_motd() {
    cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/motd
This ISO is based on ArchLinux ISO modified to provide Installation Environment for [38;2;23;147;209mCachyOS[0m.
https://cachyos.org

CachyOS Archiso Sources:
https://github.com/cachyos/cachyos-live-iso

ArchLinux ISO Source:
https://gitlab.archlinux.org/archlinux/archiso

Calamares is used as GUI installer:
https://github.com/calamares/calamares

Live environment will start now and let you install [38;2;23;147;209mCachyOS[0m to disk.

Getting help at the forum: https://discuss.cachyos.org

Welcome to your [38;2;23;147;209mCachyOS[0m!

[41m [41m [41m [40m [44m [40m [41m [46m [45m [41m [46m [43m [41m [44m [45m [40m [44m [40m [41m [44m [41m [41m [46m [42m [41m [44m [43m [41m [45m [40m [40m [44m [40m [41m [44m [42m [41m [46m [44m [41m [46m [47m [0m
EOF
}

fetch_cachyos_mirrorlist() {
    mkdir -p ${src_dir}/archiso/airootfs/etc/pacman.d
    local _mirrorlist_url="https://github.com/CachyOS/CachyOS-PKGBUILDS/raw/master/cachyos-mirrorlist/cachyos-mirrorlist"

    curl -sSL "${_mirrorlist_url}" > ${src_dir}/archiso/airootfs/etc/pacman.d/cachyos-mirrorlist
}

change_grub_version() {
    local _version="$1"
    sed -i "s/CACHYOS_VERSION=\".*\"/CACHYOS_VERSION=\"${_version}\"/" ${src_dir}/archiso/grub/grub.cfg
}

generate_environment() {
    local _profile="$1"
    if [ "$_profile" == "desktop" ] || [ "$_profile" == "fenrir" ]; then
        cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/environment
ZPOOL_VDEV_NAME_PATH=1
EOF
    fi
}

generate_version_tag() {
    local _profile="$1"
    local _version="$2"
    if [ "$_profile" == "desktop" ] || [ "$_profile" == "fenrir" ]; then
        echo "${_version}" > ${src_dir}/archiso/airootfs/etc/version-tag
    fi
}

generate_edition_tag() {
    local _edition="$1"
    echo "${_edition}" > ${src_dir}/archiso/airootfs/etc/edition-tag
}

modify_mkarchiso() {
    local _is_hack_applied="$(grep -q 'archlinux-keyring-wkd-sync.timer' /usr/bin/mkarchiso; echo $?)"
    if [ $_is_hack_applied -ne 0 ]; then
        msg "Patching mkarchiso with disabled arch keyrings timer..."

        sudo sed 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' -i /usr/bin/mkarchiso
    else
        msg "mkarchiso is already patched!"
    fi
}

prepare_profile(){
    profile=$1

    info "Profile: [%s]" "${profile}"

    local _iso_version="$(date +%y%m%d)"
    change_grub_version "${_iso_version}"

    # Fetch up-to-date version of CachyOS repo mirrorlist
    fetch_cachyos_mirrorlist

    generate_motd

    rm -f ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    if [ "$profile" == "desktop" ]; then
        cp ${src_dir}/archiso/packages_desktop.x86_64 ${src_dir}/archiso/packages.x86_64
        ln -sf /usr/lib/systemd/system/plasmalogin.service ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    elif [ "$profile" == "fenrir" ]; then
        # limine and limine-mkinitcpio-hook are excluded from the live
        # image's own package list. Their post-install pacman hook deploys
        # Limine onto a mounted ESP, which doesn't exist while mkarchiso is
        # just building a squashfs, so it fails loudly (harmlessly, but
        # noisily) every build. The live ISO boots via mkarchiso's own
        # SYSLINUX/GRUB setup, not a pacstrapped Limine, so it doesn't need
        # them anyway.
        grep -vE '^(limine|limine-mkinitcpio-hook)$' ${src_dir}/archiso/packages_fenrir.x86_64 > ${src_dir}/archiso/packages.x86_64
        ln -sf /usr/lib/systemd/system/sddm.service ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
        # fenrir-installer pacstraps the same package list the live image
        # itself was built from, so the installed system always matches
        # what's already been verified booting live. Baking a copy into
        # the airootfs is how it reads that list at install time. Unlike
        # packages.x86_64 above, this keeps limine/limine-mkinitcpio-hook,
        # since this list is used to pacstrap the real target disk, which
        # does have a real ESP for that hook to deploy onto, and provides
        # limine-mkinitcpio/limine-update, which limine-entry-tool alone
        # does not ship.
        cp ${src_dir}/archiso/packages_fenrir.x86_64 ${src_dir}/archiso/airootfs/etc/fenrir-packages.x86_64
        # fenrir-installer re-pacstraps this same package list onto the
        # real target disk from *within* the booted live system, wherever
        # that's actually running, so the local packages need to physically
        # ship inside the live image too, not just be reachable from this
        # build host. archiso/airootfs/etc/pacman.conf is the live image's
        # own real /etc/pacman.conf (copied in as-is, unlike
        # archiso/pacman.conf which mkarchiso only uses for a temporary
        # build-time work config), so its [fenrir-local] entry points here
        # instead, at this baked-in copy.
        rm -rf ${src_dir}/archiso/airootfs/opt/fenrir-local-repo
        mkdir -p ${src_dir}/archiso/airootfs/opt/fenrir-local-repo
        cp ${src_dir}/local-repo/*.pkg.tar.zst ${src_dir}/archiso/airootfs/opt/fenrir-local-repo/
        cp -P ${src_dir}/local-repo/fenrir-local.db ${src_dir}/local-repo/fenrir-local.db.tar.gz \
            ${src_dir}/local-repo/fenrir-local.files ${src_dir}/local-repo/fenrir-local.files.tar.gz \
            ${src_dir}/archiso/airootfs/opt/fenrir-local-repo/
        # archiso/airootfs/etc/pacman.conf is shared with the unrelated
        # "desktop" profile, which has no local-repo/ and shouldn't get a
        # dangling repo entry, so this only gets added here, not committed
        # to the tracked file. Guarded so repeated fenrir builds in the
        # same checkout don't append it twice.
        if ! grep -q "^\[fenrir-local\]$" ${src_dir}/archiso/airootfs/etc/pacman.conf; then
            sed -i "/^\[cachyos\]$/i [fenrir-local]\nSigLevel = Optional TrustAll\nServer = file:///opt/fenrir-local-repo\n" \
                ${src_dir}/archiso/airootfs/etc/pacman.conf
        fi
    else
        die "Unknown profile: [%s]" "${profile}"
    fi

    generate_environment "${profile}"

    # Write out version to be able to check ISO version
    generate_version_tag "${profile}" "${_iso_version}"

    # Write out edition to be able to check ISO edition
    generate_edition_tag "${profile}"

    iso_file=$(gen_iso_fn).iso
}

run_build() {
    prepare_profile "$1"
    local _profile="$1"

    msg "Prepare [work: ${work_dir}, out: ${outFolder}]"

    if $verbose; then
        msg2 "Making mkarchiso verbose"
        sudo sed -i 's/quiet="y"/quiet="n"/g' /usr/bin/mkarchiso
    fi

    if $clean_first; then
        msg2 "Deleting the build folder if one exists - takes some time"
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
    fi

    msg2 "Copying the Archiso folder to build work"
    mkdir -p ${work_dir}
    cp -r archiso ${work_dir}/archiso

    if [ "$_profile" == "fenrir" ]; then
        # [fenrir-local] is injected into the work copy only, not the
        # tracked archiso/pacman.conf, since that file is shared with the
        # unrelated "desktop" profile (built in CI, which has no
        # local-repo/ and shouldn't need one). Using an absolute host path
        # here is fine: this pacman.conf is only ever used directly by
        # build-time pacstrap on this same host, never copied into a live
        # image (that's archiso/airootfs/etc/pacman.conf, a different
        # file, which points at the live-filesystem copy instead).
        cat <<EOF >> ${work_dir}/archiso/pacman.conf

# Locally prebuilt AUR packages Caelestia and fenrir-installer need (see
# build-local-repo.sh). Listed last as an override doesn't apply here;
# pacman.conf repo order only matters for same-named package precedence.
[fenrir-local]
SigLevel = Optional TrustAll
Server = file://${src_dir}/local-repo
EOF
    fi

    msg "Start [Build ISO]"

    # insert removal of archlinux keyrings timer on the ISO before pack
    modify_mkarchiso

    [ -d "$outFolder/$_profile" ] || mkdir -p "$outFolder/$_profile"
    cd ${work_dir}/archiso/
    sudo mkarchiso -v -w ${work_dir} -o "$outFolder/$_profile" ${work_dir}/archiso/
    sudo chown $USER $outFolder

    cp ${work_dir}/iso/fenrir/pkglist.x86_64.txt "$outFolder/$_profile/$(gen_iso_fn).pkgs.txt"
    mv "$outFolder/$_profile/fenrir-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-x86_64.iso" "$outFolder/$_profile/${iso_file}"

    msg "Done [Build ISO] ${iso_file}"
    msg "Finished building [%s]" "${_profile}"

    cd "$outFolder/$_profile"
    for f in $(find . -maxdepth 1 -name '*.iso' | cut -d'/' -f2); do
        if [[ ! -e $f.sha256 ]]; then
            create_chksums $f
        elif [[ $f -nt $f.sha256 ]]; then
            create_chksums $f
        else
            info "checksums for [$f] already created"
        fi
        if [[ ! -e $f.sig ]]; then
            sign_with_key $f
        elif [[ $f -nt $f.sig ]]; then
            rm $f.sig
            sign_with_key $f
        else
            info "signature file for [$f] already created"
        fi
    done
    show_elapsed_time "${FUNCNAME}" "${timer_start}"
    if [[ "$build_in_ram" == "true" && "$remove_build_dir" == "false" ]]; then
        msg "!!! Remember to remove $work_dir !!!"
        msg2 "sudo rm -rf $work_dir"
    fi
    if [[ "$remove_build_dir" == "true" ]]; then
        msg "Automatically removing build directory ($work_dir)..."
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
        msg2 "Removed"
    fi
}

gen_iso_fn(){
    local vars=() name
    vars+=("fenrir")

    vars+=("linux")
    vars+=("$(date +%y%m%d)")

    for n in ${vars[@]}; do
        name=${name:-}${name:+-}${n}
    done

    echo $name
}
