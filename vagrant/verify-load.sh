#!/bin/bash
# verify-load.sh - destructive load test for the rcraid DKMS module.
#
# Inserts rcraid.ko and reports success/failure to BOTH stdout and the
# VM console (/dev/console). The driver's PCI probing may break the
# virtio network device on machines without RAID hardware, so output is
# mirrored to the console where it can be read back via a libvirt
# screenshot even if ssh dies. The result code is also written to
# /root/rcraid-smoke.rc.
#
# load-test.sh runs this detached (nohup) so a dead NIC cannot abort
# the rest of the pipeline.
#
# Known quirks of the AMD blob (documented in README):
#   * SUSE kernels refuse unsupported modules without
#     --allow-unsupported.
#   * On legacy-BIOS VMs the blob can NULL-call during init
#     (is_var_not_supported) - UEFI systems do not hit this path.
set -u

KVER="$(uname -r)"
RC=0

log() { echo "$@" | tee /dev/console 2>/dev/null || echo "$@"; }

# SUSE kernels refuse out-of-tree modules unless --allow-unsupported is
# given (or allow_unsupported_modules=1 is set in modprobe.d); EL accepts
# plain modprobe. Try the plain form first, then the SUSE policy flag.
modprobe -v rcraid 2>&1 | tee /dev/console 2>/dev/null || \
    modprobe --allow-unsupported -v rcraid 2>&1 | tee /dev/console 2>/dev/null

# give init a moment even if the modprobe process crashed
sleep 5

if [ -d /sys/module/rcraid ] || lsmod | grep -q '^rcraid'; then
    log "RCRAID_SMOKE: rcraid.ko loaded on $KVER"
    lsmod | grep '^rcraid' | tee /dev/console 2>/dev/null
    dmesg | tail -12 | tee /dev/console 2>/dev/null
    if modprobe -r rcraid 2>/dev/null; then
        log "RCRAID_SMOKE: module unloaded cleanly"
    else
        log "RCRAID_SMOKE: module still loaded (unload skipped/failed - driver quirk)"
    fi
else
    log "RCRAID_SMOKE: rcraid did not register in lsmod"
    dmesg | tail -25 | tee /dev/console 2>/dev/null
    RC=1
fi

echo "$RC" > /root/rcraid-smoke.rc
sync
exit "$RC"
