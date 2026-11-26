set -u
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do
 for file in "$txn/candidate/global/lib/node_modules/openclaw/node_modules/sqlite-vec/package.json" "$txn/candidate/global/lib/node_modules/openclaw/node_modules/sqlite-vec-linux-x64/vec0.so"; do [ ! -e "$file" ] || stat -c '%a %U:%G %n' "$file"; done
done
