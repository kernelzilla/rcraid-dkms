#!/bin/bash
# build-test.sh - phase 2 provisioning for the rcraid-dkms test VMs.
#
# Runs *after* the post-provisioning `vagrant reload`, i.e. on the newest
# installed kernel. Builds the source tarball + RPM, installs the RPM
# (which triggers dkms add/build/install through %post) and runs the
# verification suite. Built artifacts are staged in /root/rpmbuild and
# copied to /tmp/rcraid-artifacts for the host-side pull script.
set -euxo pipefail

SRC=/home/vagrant/rcraid-dkms
TOPDIR=/root/rpmbuild
ART=/tmp/rcraid-artifacts

# rpmbuild tree
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$ART"

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

# ---- destructive load test ----------------------------------------------
# Reinstall the rpm (verify.sh removed it) so the module is present, then
# insert it. The driver's PCI probing may kill the virtio NIC on machines
# without RAID hardware, so this runs detached and logs to the VM console
# (readable via `virsh screenshot`); the result code lands in
# /tmp/rcraid-smoke.rc.
rpm -Uvh --replacepkgs --replacefiles "$RPM"
rm -f /tmp/rcraid-smoke.rc
nohup bash "$SRC/vagrant/verify-load.sh" >/dev/null 2>&1 &
sleep 45
if [ -f /tmp/rcraid-smoke.rc ]; then
    echo "load test result: $(cat /tmp/rcraid-smoke.rc) (0=ok)"
    [ "$(cat /tmp/rcraid-smoke.rc)" = "0" ]
else
    echo "load test result unknown - NIC probably died; check console screenshot"
fi
