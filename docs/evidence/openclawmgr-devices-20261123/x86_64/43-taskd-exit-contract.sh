set -u
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' -e '@.data.exit_code'
