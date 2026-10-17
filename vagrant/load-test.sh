#!/bin/bash
# load-test.sh - trigger the destructive modprobe smoke test in the guest.
#
# Runs *after* build-test.sh and only once the build artifacts have been
# pulled to the host: verify-load.sh's modprobe may kill the virtio NIC
# on machines without RAID hardware, leaving the guest unreachable over
# ssh afterwards. Reinstalls the freshly built package first (verify.sh
# removed it during the uninstall checks), then spawns verify-load.sh
# detached and waits up to ~45s for the result code in
# /root/rcraid-smoke.rc.
set -euo pipefail

ART=/root/rcraid-artifacts

if command -v apt-get >/dev/null 2>&1; then
    DEB="$(find "$ART" -name 'rcraid-dkms_*.deb' | head -n1)"
    test -n "$DEB"
    apt-get install -y "$DEB"
else
    RPM="$(find "$ART" -name 'rcraid-dkms-*.rpm' ! -name '*.src.rpm' | head -n1)"
    test -n "$RPM"
    rpm -Uvh --replacepkgs --replacefiles "$RPM"
fi

rm -f /root/rcraid-smoke.rc
nohup bash /home/vagrant/rcraid-dkms/vagrant/verify-load.sh >/dev/null 2>&1 &

for _ in $(seq 45); do
    [ -f /root/rcraid-smoke.rc ] && break
    sleep 1
done

if [ -f /root/rcraid-smoke.rc ]; then
    echo "load test result: $(cat /root/rcraid-smoke.rc) (0=ok)"
    [ "$(cat /root/rcraid-smoke.rc)" = "0" ]
else
    echo "load test result unknown - NIC probably died; check console screenshot"
fi
