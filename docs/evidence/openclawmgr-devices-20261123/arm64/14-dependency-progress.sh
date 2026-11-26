set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== latest npm install debug'
last=''
for f in "$base"/npm-cache/_logs/*.log; do [ ! -f "$f" ] || { if grep -q 'title npm install' "$f"; then last="$f"; fi; }; done
if [ -n "$last" ]; then tail -n 18 "$last"; fi
printf '%s\n' '== root task'
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
