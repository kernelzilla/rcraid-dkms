#!/bin/bash
# verify.sh - post-install verification for the rcraid-dkms RPM.
#
# Checks, in order:
#   1. the rpm is installed and ships the expected files
#   2. DKMS reports the module built *and installed* for the running kernel
#   3. the module object exists under /lib/modules/<kver>/
#   4. depmod/modinfo resolve the module
#   5. removing the rpm removes the dkms module and the .ko from the tree
#
# The actual `modprobe rcraid` load test lives in verify-load.sh: on VMs
# without RAID hardware the driver's PCI probing may break the virtio
# network device, so it must run after everything else and logs to the
# VM console.
#
# Safe to run standalone on any rpm-based distro after `rpm -i rcraid-dkms-*.rpm`.
set -euo pipefail

KVER="$(uname -r)"
PKG=rcraid-dkms
MOD=rcraid

echo "=== [1/5] package metadata ==="
rpm -q "$PKG"
rpm -ql "$PKG" | grep -E 'dkms.conf|Makefile|rcblob'

echo "=== [2/5] dkms status ==="
dkms status
dkms status "$MOD" | tee /tmp/dkms-status.out
grep -q "installed" /tmp/dkms-status.out
# dkms status output: "rcraid/<ver>, <kver>, x86_64: installed"
grep -q "$KVER.*installed" /tmp/dkms-status.out

echo "=== [3/5] module file in /lib/modules/$KVER ==="
KO="$(find "/lib/modules/$KVER" -name 'rcraid.ko*' | head -n1)"
test -n "$KO"
echo "module: $KO"

echo "=== [4/5] depmod + modinfo ==="
depmod -a "$KVER"
modinfo rcraid | grep -E 'filename|version|license'

echo "=== [5/5] package removal ==="
rpm -e "$PKG"
if dkms status "$MOD" | grep -q .; then
    echo "FAIL: dkms module still registered after rpm -e" >&2
    exit 1
fi
if find "/lib/modules/$KVER" -name 'rcraid.ko*' | grep -q .; then
    echo "FAIL: rcraid.ko still present after rpm -e" >&2
    exit 1
fi
echo "module and dkms entry removed cleanly"

echo "=== ALL CHECKS PASSED on $KVER ==="
