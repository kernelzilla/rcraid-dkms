#!/bin/bash
# pull-artifacts.sh - fetch built RPMs/tarballs from a test VM into dist/.
#
# Usage:  vagrant/pull-artifacts.sh <vm-name>
# Runs on the HOST. Streams the guest's /root/rcraid-artifacts (populated by
# build-test.sh) over ssh into dist/<short-vm-name>/.
set -euo pipefail

cd "$(dirname "$0")/.."
VM="${1:?usage: $0 <vm-name>}"
SHORT="${VM#rcraid-}"
OUT="dist/$SHORT"

mkdir -p "$OUT"
if ! vagrant ssh "$VM" -c 'sudo tar -C /root/rcraid-artifacts -cf - . 2>/dev/null' \
    | tar -xf - -C "$OUT"; then
    echo "WARNING: ssh to $VM failed; no artifacts pulled" >&2
fi

# modprobe smoke-test evidence: the result code + a VM console screenshot.
RC="$(vagrant ssh "$VM" -c 'sudo cat /root/rcraid-smoke.rc 2>/dev/null' || true)"
if [ -n "$RC" ]; then
    printf '%s' "$RC" > "$OUT/smoke.rc"
fi
DOMAIN=$(virsh -c qemu:///system list --all --name 2>/dev/null \
    | grep -E "(^|_)${VM}$" | head -1 || true)
if [ -n "$DOMAIN" ] \
    && virsh -c qemu:///system domstate "$DOMAIN" 2>/dev/null | grep -q running; then
    virsh -c qemu:///system screenshot "$DOMAIN" "$OUT/console.png" \
        >/dev/null 2>&1 || true
fi
echo "==> artifacts for $VM:"
find "$OUT" -type f -printf '    %p  (%k KiB)\n'
