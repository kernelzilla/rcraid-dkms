#!/bin/bash
# kernel-versions.sh - emit the latest kernel.org release per stable and
# longterm series, space-separated on stdout. Used by the vagrant
# provisioner to decide which vanilla-kernel header packages to install,
# so the CI matrix always tests the current upstream series.
set -euo pipefail

curl -fsSL https://www.kernel.org/releases.json | python3 -c '
import json, sys

seen, out = set(), []
for r in json.load(sys.stdin)["releases"]:
    if r.get("moniker") not in ("stable", "longterm"):
        continue
    v = r["version"]
    series = v.rsplit(".", 1)[0]
    if series not in seen:
        seen.add(series)
        out.append(v)
print(" ".join(out))
'
