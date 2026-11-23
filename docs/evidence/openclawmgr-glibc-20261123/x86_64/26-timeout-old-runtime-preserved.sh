set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
cp /var/log/tasks/openclawmgr.log "$root/logs/first-origin-install-timeout.log"
test ! -L "$base/current"
test ! -d /tmp/openclawmgr-installer.lock
printf 'old_gateway_pid='
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid'
token="$(jsonfilter -i "$base/data/.openclaw/openclaw.json" -e '@.gateway.auth.token')"
HOME="$base/data" OPENCLAW_STATE_DIR="$base/data/.openclaw" OPENCLAW_CONFIG_PATH="$base/data/.openclaw/openclaw.json" "$base/node/bin/node" "$base/global/lib/node_modules/openclaw/openclaw.mjs" gateway health --url ws://127.0.0.1:19189 --token "$token"
