set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== recent task log'
tail -n 22 /var/log/tasks/openclawmgr.log 2>/dev/null || true
printf '%s\n' '== package and ownership'
for d in "$base"/.install.*; do
 [ -d "$d" ] || continue
 ls -lh "$d"/openclaw*.tgz "$d"/pack.json "$d"/candidate/global/lib/node_modules/openclaw/package.json 2>/dev/null || true
 stat -c '%u:%g %a %n' "$d"/candidate/node "$d"/candidate/node/bin/node 2>/dev/null || true
done
printf '%s\n' '== node gateway state'
/etc/init.d/tasks task_status openclawmgr 2>/dev/null | jsonfilter -e '@.running' || true
