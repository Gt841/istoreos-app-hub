#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
exec /var/cache/build-cache/run.sh --project "$root" -- node "$root/scripts/ui-design-prepare.cjs"
