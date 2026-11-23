set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
su -s /bin/sh -c "cd $base/probe_modules && $base/probe-node/bin/node $base/probe_modules/probe.cjs" openclawmgr
printf 'boot='; cat /proc/sys/kernel/random/boot_id
