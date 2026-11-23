set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
readlink "$base/current" > "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-current"
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid' > "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/assets/before-network-failure-pid"
/etc/init.d/tasks task_add openclawmgr 'env HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9 NO_PROXY= no_proxy= npm_config_fetch_retries=0 npm_config_fetch_timeout=2000 /usr/libexec/istorec/openclawmgr.sh upgrade'
printf '%s\n' 'Submitted per-process proxy failure; no system proxy or firewall changed'
