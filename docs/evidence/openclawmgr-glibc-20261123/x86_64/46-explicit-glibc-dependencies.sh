set -u
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do
 pkg="$txn/candidate/global/lib/node_modules/openclaw/node_modules"
 printf '%s\n' '== npm target libc'
 "$txn/candidate/node/bin/node" -p 'process.env.npm_config_libc'
 printf '%s\n' '== selected Sharp packages'
 ls "$pkg/@img" 2>/dev/null || true
done
