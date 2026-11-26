set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
base="/mnt/vio4-0/OpenClawMgr-glibc-acceptance-20261123"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
tar -xf "$root/assets/candidate-x86_64.tar" -C /
chmod 600 /etc/config/openclawmgr
cp "$root/assets/node-v24.22.1-linux-x64.tar.xz" "$base/npm-cache/node-24.22.1-x64-glibc.tar.xz"
uci set openclawmgr.main.enabled=1
uci set openclawmgr.main.base_dir="$base"
uci set openclawmgr.main.install_accelerated=0
uci set openclawmgr.main.port=19189
uci set openclawmgr.main.bind=loopback
uci commit openclawmgr

old="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
cp -a "$old/current/node" "$base/node"
cp -a "$old/current/global" "$base/global"
cp -a "$old/data" "$base/data"
# Copy the legacy test config without exposing its token.
sed "s|$old|$base|g" "$old/data/.openclaw/openclaw.json" > "$base/data/.openclaw/openclaw.json"
chown -R openclawmgr:openclawmgr "$base/data"
/etc/init.d/openclawmgr start
printf 'legacy_gateway_pid='
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid'

printf '%s\n' 'candidate deployed'
/etc/init.d/tasks task_add openclawmgr '/usr/libexec/istorec/openclawmgr.sh upgrade'
printf '%s\n' 'real glibc install task submitted'
