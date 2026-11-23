set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
[ "$(/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running')" != true ]
[ ! -d /var/lock/openclawmgr.lock ]
for txn in "$base"/.install.*; do [ ! -d "$txn" ]; done
printf '%s\n' 'idle, no transaction journal'
