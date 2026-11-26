set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
old="$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-current")"
current="$(readlink "$base/current")"
test "$current" != "$old"
test "$(readlink "$base/previous")" = "$old"
test "$(cat "$base/data/acceptance-sentinel")" = original
release="$(basename "$current")"
test "$(tar -xOf "$base/backups/$release/data.tar" ./acceptance-sentinel)" = original
cp /var/log/tasks/openclawmgr.log "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/10-successful-upgrade.log"
cp "$base/current/receipt.json" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/10-upgrade-receipt.json"
printf '%s\n' 'upgrade passed: new current, old previous, original data and original snapshot'
set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== task status'
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running'
printf '%s\n' '== receipt'
jsonfilter -i "$base/current/receipt.json" -e '@.version' -e '@.arch' -e '@.node' -e '@.nativeChecks'
printf '%s\n' '== pointers'
readlink "$base/current"
readlink "$base/previous"
printf '%s\n' '== actual process'
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
test -n "$pid"
sed -n '/^Uid:/p' "/proc/$pid/status"
printf '%s\n' '== actual Gateway health'
token="$(jsonfilter -i "$base/data/.openclaw/openclaw.json" -e '@.gateway.auth.token')"
HOME="$base/data" OPENCLAW_HOME="$base/data" OPENCLAW_STATE_DIR="$base/data/.openclaw" OPENCLAW_CONFIG_PATH="$base/data/.openclaw/openclaw.json" "$base/node/bin/node" "$base/global/lib/node_modules/openclaw/openclaw.mjs" gateway health --url ws://127.0.0.1:19189 --token "$token"
printf '%s\n' '== candidate source owner'
stat -c '%u:%g %n' "$base/node/bin/node"
printf '%s\n' '== final task lines'
tail -n 8 /var/log/tasks/openclawmgr.log
