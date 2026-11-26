set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
/usr/libexec/istorec/openclawmgr.sh restart
printf '%s\n' '== after extension restoration / public manager restart'
su -s /bin/sh -c "cd $base/data && $base/node/bin/node $base/data/openclaw-vector-check.mjs $base/global/lib/node_modules/openclaw" openclawmgr
printf '%s\n' '== current process uid'
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
sed -n '/^Uid:/p' "/proc/$pid/status"
test ! -d /tmp/openclawmgr-installer.lock
printf '%s\n' 'manager restart and vector recheck passed'
