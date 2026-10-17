#!/bin/bash
# pull-artifacts.sh - fetch built RPMs/tarballs from a test VM into dist/.
#
# Usage:  vagrant/pull-artifacts.sh <vm-name>
# Runs on the HOST. Streams the guest's /tmp/rcraid-artifacts (populated by
# build-test.sh) over ssh into dist/<short-vm-name>/.
set -euo pipefail

cd "$(dirname "$0")/.."
VM="${1:?usage: $0 <vm-name>}"
SHORT="${VM#rcraid-}"
OUT="dist/$SHORT"

mkdir -p "$OUT"
vagrant ssh "$VM" -c 'sudo tar -C /tmp/rcraid-artifacts -cf - . 2>/dev/null' \
    | tar -xf - -C "$OUT"

# modprobe smoke-test evidence: the result code + a VM console screenshot.
vagrant ssh "$VM" -c 'cat /tmp/rcraid-smoke.rc 2>/dev/null' \
    > "$OUT/smoke.rc" 2>/dev/null || true
if virsh -c qemu:///system domstate "rcraid-dkms_$VM" 2>/dev/null | grep -q running; then
    virsh -c qemu:///system screenshot "rcraid-dkms_$VM" "$OUT/console.png" \
        >/dev/null 2>&1 || true
fi
echo "==> artifacts for $VM:"
find "$OUT" -type f -printf '    %p  (%k KiB)\n'
