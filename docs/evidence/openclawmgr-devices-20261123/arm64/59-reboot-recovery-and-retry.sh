set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== reboot observation'
uptime
printf '%s\n' '== journal phases'
for txn in "$base"/.install.*; do
 [ ! -d "$txn" ] || { basename "$txn"; cat "$txn/phase"; }
done
printf '%s\n' '== managed Gateway'
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' || true
printf '%s\n' '== pstore names'
ls /sys/fs/pstore 2>/dev/null || true
printf '%s\n' '== recovery'
/usr/libexec/istorec/openclawmgr.sh recover_install
cp "$base/log/installer.log" "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/logs/08-reboot-preparation-recovery.log"
test ! -d /tmp/openclawmgr-installer.lock
for txn in "$base"/.install.*; do [ ! -d "$txn" ]; done
printf '%s\n' 'preparation recovery passed'
ACCEPTANCE_OP=install CANDIDATE_CONTROLLER="/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
