set -eu
test_root='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123'
cp /var/log/tasks/openclawmgr.log "$test_root/logs/03-first-native-gate.log"
/etc/init.d/tasks task_add openclawmgr 'umask 022; /usr/libexec/istorec/openclawmgr.sh install' -1
sleep 1
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running'
