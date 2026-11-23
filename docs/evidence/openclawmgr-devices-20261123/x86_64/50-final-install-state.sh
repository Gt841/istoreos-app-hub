set -u
printf 'task='
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
tail -n 12 /var/log/tasks/openclawmgr.log
