#!/bin/bash
# build-test.sh - phase 2 provisioning for the rcraid-dkms test VMs.
#
# Runs *after* the post-provisioning `vagrant reload`, i.e. on the newest
# installed kernel. Builds the source tarball + RPM, installs the RPM
# (which triggers dkms add/build/install through %post) and runs the
# verification suite. Built artifacts are staged in /root/rpmbuild and
# copied to /root/rcraid-artifacts for the host-side pull script. The
# destructive modprobe smoke test is deliberately NOT run here - see
# vagrant/load-test.sh.
set -euxo pipefail

SRC=/home/vagrant/rcraid-dkms
TOPDIR=/root/rpmbuild
ART=/root/rcraid-artifacts

mkdir -p "$ART"

# ---- Debian/Ubuntu path: build + install the .deb -----------------------
# (xanmod test VM and any apt-based guest). dpkg-buildpackage produces the
# dkms package; installing it triggers the module build via dh_dkms hooks.
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    cd "$SRC"
    dpkg-buildpackage -us -uc -b
    DEB="$(find "$SRC/.." -maxdepth 1 -name 'rcraid-dkms_*.deb' | head -n1)"
    test -n "$DEB"
    apt-get install -y "$DEB"

    bash "$SRC/vagrant/verify.sh"

    cp "$SRC/.."/*.deb "$ART/" 2>/dev/null || true
    uname -r > "$ART/kernel.txt"
    echo "=== artifacts in $ART ==="
    ls -la "$ART"

    # reinstall (verify.sh removed it) then detached load test
    apt-get install -y "$DEB"

    # Multi-kernel check: dkms-build the module against *every* installed
    # headers tree (vanilla VMs install all stable+longterm series), not
    # just the running kernel. Results land in kernels.txt artifact.
    DVER="$(dkms status rcraid | head -1 | cut -d/ -f2 | cut -d, -f1)"
    for d in /lib/modules/*/build; do
        kver="$(basename "$(dirname "$d")")"
        [ "$kver" = "$(uname -r)" ] && continue
        if dkms build -m rcraid -v "$DVER" -k "$kver" >>"$ART/kernels.log" 2>&1; then
            echo "$kver BUILD OK" | tee -a "$ART/kernels.txt"
        else
            echo "$kver BUILD FAIL" | tee -a "$ART/kernels.txt"
        fi
    done
    cat "$ART/kernels.txt" 2>/dev/null || true
    exit 0
fi

# rpmbuild tree
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# ---- source tarball + spec ---------------------------------------------
TARBALL="$("$SRC/rpm/mksources.sh" "$TOPDIR/SOURCES")"
cp "$SRC/rpm/rcraid-dkms.spec" "$TOPDIR/SPECS/"

# ---- build binary + source RPM -----------------------------------------
rpmbuild -ba --define "_topdir $TOPDIR" "$TOPDIR/SPECS/rcraid-dkms.spec"

# ---- install the freshly built RPM -------------------------------------
RPM="$(find "$TOPDIR/RPMS" -name 'rcraid-dkms-*.rpm' | head -n1)"
test -n "$RPM"
rpm -Uvh --replacepkgs --replacefiles "$RPM"

# ---- verify -------------------------------------------------------------
bash "$SRC/vagrant/verify.sh"

# ---- stage artifacts for the host (BEFORE the NIC-killing load test) ----
cp "$RPM" "$ART/"
find "$TOPDIR/SRPMS" -name '*.src.rpm' -exec cp {} "$ART/" \;
cp "$TARBALL" "$ART/"

echo "=== artifacts in $ART ==="
ls -la "$ART"

# The destructive modprobe smoke test lives in vagrant/load-test.sh and
# runs *after* the artifacts have been pulled to the host: the driver's
# PCI probing may kill the virtio NIC, which would make this guest
# unreachable over ssh.
