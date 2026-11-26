set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
cp /var/log/tasks/openclawmgr.log "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/06-successful-install.log"
cp "$base/current/receipt.json" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/06-install-receipt.json"
readlink "$base/current" > "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-current"
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid' > "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-pid"
printf 'original\n' > "$base/data/acceptance-sentinel"
chown openclawmgr:openclawmgr "$base/data/acceptance-sentinel"
ACCEPTANCE_OP=upgrade CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
sleep 3
ACCEPTANCE_OP=status CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
ACCEPTANCE_OP=cancel_install CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
test "$(readlink "$base/current")" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-current")"
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
test "$pid" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-upgrade-pid")"
test ! -d /tmp/openclawmgr-installer.lock
cp /var/log/tasks/openclawmgr.log "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/07-cancel-upgrade.log"
printf '%s\n' 'cancel passed: original current and Gateway pid preserved'
