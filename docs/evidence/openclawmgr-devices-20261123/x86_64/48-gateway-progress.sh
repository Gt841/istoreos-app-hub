set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'running='
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
printf '%s\n' '== native/script progress'
grep -E 'Checking native|fallback|Error loading|Installation phase|Checking the candidate|Installation committed|finished|^> .*postinstall|^Downloading lib' /var/log/tasks/openclawmgr.log | tail -n 10 || true
printf '%s\n' '== tail'
tail -n 5 /var/log/tasks/openclawmgr.log
if [ -f "$base/current/receipt.json" ]; then jsonfilter -i "$base/current/receipt.json" -e '@.version' -e '@.nativeChecks'; fi
