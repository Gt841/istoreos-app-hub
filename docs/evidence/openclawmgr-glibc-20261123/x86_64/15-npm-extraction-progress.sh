set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'task='; /etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
tail -n 9 /var/log/tasks/openclawmgr.log
for txn in "$base"/.install.*; do [ ! -d "$txn/candidate/global" ] || du -sk "$txn/candidate/global"; done
