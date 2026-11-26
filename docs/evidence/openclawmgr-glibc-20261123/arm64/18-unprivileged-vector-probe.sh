set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'umask='; umask
for file in "$base/probe_modules" "$base/probe_modules/node_modules" "$base/probe_modules/node_modules/sqlite-vec" "$base/probe_modules/node_modules/sqlite-vec/package.json" "$base/probe-node/bin/node" "$base/probe-node/node-loader.cjs"; do stat -c '%a %U:%G %n' "$file"; done
chmod -R a+rX "$base/probe_modules" "$base/probe-node"
su -s /bin/sh -c "cd $base/probe_modules && $base/probe-node/bin/node $base/probe_modules/probe.cjs" openclawmgr
