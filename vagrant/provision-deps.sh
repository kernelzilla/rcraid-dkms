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
        curl -fsSL "https://packagecloud.io/install/repositories/debian-kernels/buster/script.deb.sh" | bash
        apt-get update
        # VANILLA_KVERS=auto -> latest release per stable+longterm series
        KVERS_LIST="${VANILLA_KVERS:-auto}"
        if [ "$KVERS_LIST" = "auto" ]; then
            KVERS_LIST="$(bash /home/vagrant/rcraid-dkms/vagrant/kernel-versions.sh 2>/dev/null || echo "$VANILLA_KVER")"
        fi
        echo ">> installing headers for kernel series: $KVERS_LIST"
        for v in $KVERS_LIST; do
            apt-get install -y "linux-headers-${v}-toeirei" \
                || echo "WARNING: no headers package for $v" >&2
        done
        apt-get install -y "linux-image-${VANILLA_KVER}-toeirei" \
                           "linux-headers-${VANILLA_KVER}-toeirei"
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
