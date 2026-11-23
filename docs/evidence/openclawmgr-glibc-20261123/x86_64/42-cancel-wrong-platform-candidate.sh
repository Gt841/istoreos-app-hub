set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
cp /var/log/tasks/openclawmgr.log "$root/logs/second-install-wrong-optional-libc.log"
/usr/libexec/istorec/openclawmgr.sh cancel_install
/etc/init.d/tasks task_del openclawmgr
test ! -d /tmp/openclawmgr-installer.lock
printf 'preserved_old_pid='
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid'
