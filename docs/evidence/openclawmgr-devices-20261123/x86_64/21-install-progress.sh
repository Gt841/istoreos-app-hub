set -u
base="$(uci -q get openclawmgr.main.base_dir)"
st="$(/etc/init.d/tasks task_status openclawmgr 2>/dev/null || true)"
printf 'running='; printf '%s' "$st" | jsonfilter -e '@.running' 2>/dev/null || true
printf 'http_200_count='; grep -c 'fetch.*200' /var/log/tasks/openclawmgr.log 2>/dev/null || true
printf 'http_error_count='; grep -Ec '502|ECONN|ETIMEDOUT|npm error' /var/log/tasks/openclawmgr.log 2>/dev/null || true
printf '%s\n' '== last progress'
tail -n 12 /var/log/tasks/openclawmgr.log 2>/dev/null || true
printf '%s\n' '== committed runtime'
if [ -f "$base/current/receipt.json" ]; then
 jsonfilter -i "$base/current/receipt.json" -e '@.version' -e '@.node' -e '@.arch'
 /usr/libexec/istorec/openclawmgr.sh status
fi
