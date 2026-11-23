set -eu
[ ! -e /tmp/openclawmgr-installer.lock ]
/etc/init.d/tasks task_add openclawmgr 'umask 022; exec /usr/libexec/istorec/openclawmgr.sh install' -1
sleep 2
tail -n 12 /var/log/tasks/openclawmgr.log
