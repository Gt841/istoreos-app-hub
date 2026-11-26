set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
base="$(uci -q get openclawmgr.main.base_dir)"
test ! -d /tmp/openclawmgr-installer.lock
test ! -L "$base/current"
cp /var/log/tasks/openclawmgr.log "$root/logs/second-install-wrong-optional-libc.log"
printf 'old_gateway_pid='
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid'
tar -xf "$root/assets/backend-final-libc.tar" -C /
/etc/init.d/tasks task_add openclawmgr '/usr/libexec/istorec/openclawmgr.sh upgrade'
printf '%s\n' 'third and final full glibc candidate submitted; npm optional libc explicitly glibc'
