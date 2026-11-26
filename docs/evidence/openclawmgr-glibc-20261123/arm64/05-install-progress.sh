set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'task='; /etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
printf '%s\n' '== install progress'
grep -E 'Installation phase|Installing OpenClaw|Checking native|sqlite|Installation finished|Installation committed|Downloading lib' /var/log/tasks/openclawmgr.log | tail -n 7 || true
tail -n 4 /var/log/tasks/openclawmgr.log
printf 'boot='; cat /proc/sys/kernel/random/boot_id
