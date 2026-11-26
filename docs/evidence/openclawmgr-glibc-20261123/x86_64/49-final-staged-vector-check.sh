set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do
 [ -d "$txn/candidate/node" ] || continue
 timeout -k 2 30 "$txn/candidate/node/bin/node" /usr/share/openclawmgr/runtime-check.cjs native "$txn/candidate/global" "$txn/resolved.json"
done
