set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
ACCEPTANCE_OP=cancel_install CANDIDATE_CONTROLLER="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
test "$(readlink "$base/current")" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-current")"
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-pid")"
test ! -e "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/npm-cache-before-network-fault"
mv "$base/npm-cache" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/npm-cache-before-network-fault"
mkdir -m 700 "$base/npm-cache"
/etc/init.d/tasks task_add openclawmgr 'env HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9 NO_PROXY= no_proxy= npm_config_fetch_retries=0 npm_config_fetch_timeout=2000 /usr/libexec/istorec/openclawmgr.sh upgrade'
printf '%s\n' 'Cached requests tolerated broken proxy; retesting with a separate empty cache, original cache retained'
