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
else
    echo "ERROR: unsupported distro - neither dnf nor zypper found" >&2
    exit 1
fi

echo "=== provisioning phase 1 done; running kernel: $(uname -r) ==="
