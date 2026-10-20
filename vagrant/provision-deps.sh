#!/bin/bash
# provision-deps.sh - phase 1 provisioning for the rcraid-dkms test VMs.
#
# Installs everything needed to build the DKMS RPM and the kernel module,
# then updates the kernel package so that after the subsequent
# `vagrant reload` the *running* kernel matches the installed headers.
set -euxo pipefail

if command -v dnf >/dev/null 2>&1; then
    # ---- EL8 / EL9 (RHEL, AlmaLinux, Rocky, ...) --------------------------
    # dkms lives in EPEL.
    dnf -y install epel-release
    dnf -y update kernel kernel-core kernel-modules kernel-headers || true
    dnf -y install dkms kernel-devel gcc make perl \
                   elfutils-libelf-devel rpm-build rpmdevtools

elif command -v zypper >/dev/null 2>&1; then
    # ---- openSUSE Leap 15 / SLES 15 ---------------------------------------
    zypper -n ref
    zypper -n up -y kernel-default || true
    zypper -n install -y dkms kernel-default-devel kernel-devel \
                         rpm-build gcc make
elif command -v apt-get >/dev/null 2>&1; then
    # ---- Debian / Ubuntu -------------------------------------------------
    # XANMOD=1 additionally enables the xanmod.org repo and installs
    # linux-xanmod-x64v3 (clang-built kernel -> clang/lld are installed
    # unconditionally since the module Makefile auto-detects
    # CONFIG_CC_IS_CLANG).
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y build-essential dkms debhelper devscripts \
                       rsync curl wget gpg ca-certificates \
                       clang llvm lld
    if [ "${XANMOD:-}" = "1" ]; then
        # xanmod.org repo — suite name is the distro codename (noble, ...)
        . /etc/os-release
        install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://dl.xanmod.org/archive.key \
            | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org ${VERSION_CODENAME} main" \
            > /etc/apt/sources.list.d/xanmod-release.list
        apt-get update
        apt-get install -y linux-xanmod-x64v3
        apt-get install -y linux-headers-xanmod-x64v3 \
            || apt-get install -y linux-headers-xanmod || true
    elif [ "${VANILLA_KERNEL:-}" = "1" ]; then
        # ToeiRei/kernel-deb packagecloud repo: prebuilt vanilla kernel debs
        # (linux-image|linux-headers-<kver>-toeirei). Kernels are unsigned.
        # The repo only publishes Debian dists and every dist serves the
        # same package pool, so always pin os=debian dist=bookworm: an
        # auto-detected "ubuntu noble" (or numeric "13" on trixie) 404s
        # apt-get update and kills the whole provisioner.
        curl -fsSL "https://packagecloud.io/install/repositories/debian-kernels/buster/script.deb.sh" \
            | env os=debian dist=bookworm bash
        apt-get update
        # Resolve a kernel.org release to the newest -toeirei build the
        # repo actually carries for that series; upstream point releases
        # routinely land in the repo days late (or never, for old series).
        toeirei_resolve() {
            apt-cache pkgnames "linux-image-${1%.*}." \
                | sed -nE "s/^linux-image-(${1%.*}\.[0-9]+)-toeirei\$/\1/p" \
                | sort -V | tail -1
        }
        # VANILLA_KVERS=auto -> latest release per stable+longterm series
        KVERS_LIST="${VANILLA_KVERS:-auto}"
        if [ "$KVERS_LIST" = "auto" ]; then
            KVERS_LIST="$(bash /home/vagrant/rcraid-dkms/vagrant/kernel-versions.sh 2>/dev/null || echo "$VANILLA_KVER")"
        fi
        echo ">> installing headers for kernel series: $KVERS_LIST"
        for series in $KVERS_LIST; do
            v="$(toeirei_resolve "$series")"
            if [ -n "$v" ]; then
                apt-get install -y "linux-headers-${v}-toeirei" \
                    || echo "WARNING: headers install failed for $v" >&2
            else
                echo "WARNING: no toeirei build for series $series" >&2
            fi
        done
        v="$(toeirei_resolve "$VANILLA_KVER")"
        apt-get install -y "linux-image-${v:-$VANILLA_KVER}-toeirei" \
                           "linux-headers-${v:-$VANILLA_KVER}-toeirei" \
            || echo "WARNING: no toeirei image for $VANILLA_KVER; VM keeps the stock kernel" >&2
    else
        apt-get -y dist-upgrade
        apt-get install -y linux-headers-generic \
            || apt-get install -y "linux-headers-$(uname -r)" || true
    fi
else
    echo "ERROR: unsupported distro - no dnf, zypper or apt-get found" >&2
    exit 1
fi

echo "=== provisioning phase 1 done; running kernel: $(uname -r) ==="
