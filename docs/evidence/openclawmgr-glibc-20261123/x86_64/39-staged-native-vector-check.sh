set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do
 [ -d "$txn/candidate/node" ] || continue
 "$txn/candidate/node/glibc/ld.so" --library-path "$txn/candidate/node/glibc" --list "$txn/candidate/node/bin/node.real"
 "$txn/candidate/node/bin/node" /usr/share/openclawmgr/runtime-check.cjs native "$txn/candidate/global" "$txn/resolved.json"
done
