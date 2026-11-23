set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'task='; /etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
printf '%s\n' '== installer phases'; tail -n 5 "$base/log/installer.log"
printf '%s\n' '== command tail'; tail -n 4 /var/log/tasks/openclawmgr.log
printf 'boot='; cat /proc/sys/kernel/random/boot_id
