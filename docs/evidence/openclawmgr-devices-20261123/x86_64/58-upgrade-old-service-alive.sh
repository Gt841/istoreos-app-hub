set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'old_gateway_pid='; ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid'
printf 'current='; readlink "$base/current"
tail -n 5 /var/log/tasks/openclawmgr.log
