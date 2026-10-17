#!/bin/bash
# ci-container-test.sh - rpmbuild + module-compile smoke test for CI.
#
# Runs INSIDE a container of the target distro (almalinux:8/9,
# opensuse/leap:15.6). Builds the RPM, installs it without scriptlets
# (there is no "running kernel" in a container), then compiles the
# module through DKMS against the newest installed kernel-devel.
#
# Cannot test modprobe/initramfs in a container - that is what the
# Vagrant VMs are for.
set -euxo pipefail

if command -v dnf >/dev/null 2>&1; then
    dnf -y install epel-release
    dnf -y install dkms kernel-devel gcc make perl \
                   elfutils-libelf-devel rpm-build
elif command -v zypper >/dev/null 2>&1; then
    zypper -n ref
    zypper -n install -y dkms kernel-default kernel-default-devel kernel-devel \
                         rpm-build gcc make
else
    echo "unsupported distro" >&2; exit 1
fi

# ---- source tarball + rpmbuild ------------------------------------------
./rpm/mksources.sh /tmp
mkdir -p /root/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp /tmp/rcraid-dkms-*.tar.gz /root/rpmbuild/SOURCES/
rpmbuild -ba --define "_topdir /root/rpmbuild" rpm/rcraid-dkms.spec

find /root/rpmbuild/RPMS /root/rpmbuild/SRPMS -name '*.rpm'

# ---- install w/o scriptlets, then drive DKMS for the installed kernel ----
RPM="$(find /root/rpmbuild/RPMS -name 'rcraid-dkms-*.rpm' | head -n1)"
rpm -ivh --noscripts "$RPM"

# newest installed kernel build tree
if ls /usr/src/kernels/*/Makefile >/dev/null 2>&1; then          # EL
    KVER="$(ls -d /usr/src/kernels/*/ | sort -V | tail -n1 | xargs -n1 basename)"
else                                                            # SUSE
    KVER="$(ls -d /lib/modules/*/build | sort -V | tail -n1 | cut -d/ -f4)"
fi
DKMSVER="$(basename "$(ls -d /usr/src/rcraid-*)")"
DKMSVER="${DKMSVER#rcraid-}"

echo "=== dkms build for kernel $KVER (module version $DKMSVER) ==="
dkms add     -m rcraid -v "$DKMSVER"
dkms build   -m rcraid -v "$DKMSVER" -k "$KVER"
dkms install -m rcraid -v "$DKMSVER" -k "$KVER"
dkms status  rcraid
find "/lib/modules/$KVER" -name 'rcraid.ko*'
echo "=== CI container test PASSED ==="
