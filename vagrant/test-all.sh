#!/bin/bash
# test-all.sh - build & test the rcraid-dkms RPM on every distro VM.
#
# Usage:  vagrant/test-all.sh [vm ...]
#         (default: all three: rcraid-el8 rcraid-el9 rcraid-opensuse15)
#
# For each VM: `vagrant up` (provisions deps, reboots, builds the RPM,
# installs it and runs vagrant/verify.sh in the guest), then pulls the
# built artifacts back into dist/. Only then is the destructive modprobe
# smoke test triggered (it may kill the virtio NIC); a reload restores
# networking so the smoke result + console screenshot can be pulled.
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
        timeout 240 vagrant ssh "$vm" \
            -c 'sudo bash /home/vagrant/rcraid-dkms/vagrant/load-test.sh' \
            || echo "*** $vm: load test unreachable/timed out (NIC teardown expected)"
        vagrant reload "$vm" --no-provision || true
        vagrant/pull-artifacts.sh "$vm" || true
        rc="$(cat "dist/${vm#rcraid-}/smoke.rc" 2>/dev/null || echo '?')"
        echo "=== $vm: smoke.rc=$rc"
        case "$rc" in
            0|'?') PASS+=("$vm") ;;
            *) echo "*** $vm FAILED (modprobe smoke test rc=$rc) ***"
               FAIL+=("$vm") ;;
        esac
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
