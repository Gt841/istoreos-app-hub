set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'running='
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' -e '@.openclawmgr.instances.gateway.pid'
if [ -x "$base/node/bin/node" ]; then
token="$(jsonfilter -i "$base/data/.openclaw/openclaw.json" -e '@.gateway.auth.token')"
HOME="$base/data" OPENCLAW_STATE_DIR="$base/data/.openclaw" OPENCLAW_CONFIG_PATH="$base/data/.openclaw/openclaw.json" "$base/node/bin/node" "$base/global/lib/node_modules/openclaw/openclaw.mjs" gateway health --url ws://127.0.0.1:19189 --token "$token"
fi
tail -n 8 /var/log/tasks/openclawmgr.log
