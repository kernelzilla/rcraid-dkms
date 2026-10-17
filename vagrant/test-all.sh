#!/bin/bash
# test-all.sh - build & test the rcraid-dkms RPM on every distro VM.
#
# Usage:  vagrant/test-all.sh [vm ...]
#         (default: all three: rcraid-el8 rcraid-el9 rcraid-opensuse15)
#
# For each VM: `vagrant up` (provisions deps, reboots, builds the RPM,
# installs it and runs vagrant/verify.sh in the guest), then pulls the
# built artifacts back into dist/.
set -uo pipefail

cd "$(dirname "$0")/.."
VMS="${@:-rcraid-el8 rcraid-el9 rcraid-opensuse15}"

PASS=()
FAIL=()
for vm in $VMS; do
    echo
    echo "================================================================"
    echo "=== $vm: vagrant up (provision + rpmbuild + verify) ============"
    echo "================================================================"
    if vagrant up "$vm" --provider=libvirt; then
        vagrant/pull-artifacts.sh "$vm"
        PASS+=("$vm")
    else
        echo "*** $vm FAILED (see log above) ***"
        FAIL+=("$vm")
    fi
done

echo
echo "================== SUMMARY =================="
for vm in "${PASS[@]:-}"; do [ -n "$vm" ] && echo "  PASS  $vm"; done
for vm in "${FAIL[@]:-}"; do [ -n "$vm" ] && echo "  FAIL  $vm"; done
[ "${#FAIL[@]}" -eq 0 ]
