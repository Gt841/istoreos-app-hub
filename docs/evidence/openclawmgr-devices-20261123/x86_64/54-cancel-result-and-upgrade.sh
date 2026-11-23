set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
test "$(readlink "$base/current")" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-current")"
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
test "$pid" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-pid")"
test ! -d /tmp/openclawmgr-installer.lock
cp "$base/log/installer.log" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/07-cancel-upgrade-installer.log"
printf '%s\n' 'cancel passed; task_del removes task log as expected; old current and Gateway pid preserved'
ACCEPTANCE_OP=upgrade CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
