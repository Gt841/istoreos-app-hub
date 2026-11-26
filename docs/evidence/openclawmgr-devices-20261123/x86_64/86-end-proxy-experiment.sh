set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
cp /var/log/tasks/openclawmgr.log "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/11-proxy-fault-did-not-block-routing.log"
ACCEPTANCE_OP=cancel_install CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
test "$(readlink "$base/current")" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-current")"
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-pid")"
test ! -d /tmp/openclawmgr-installer.lock
mv "$base/npm-cache" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/network-fault-attempt-cache"
mv "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/npm-cache-before-network-fault" "$base/npm-cache"
printf '%s\n' 'Original npm cache restored; old runtime/PID preserved. Proxy fault did not block ks-cli routing and is not counted as a network failure test.'
