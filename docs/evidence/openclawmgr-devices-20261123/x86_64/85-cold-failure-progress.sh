set -u
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
tail -n 20 /var/log/tasks/openclawmgr.log
