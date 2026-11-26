set -u
printf '%s\n' '== task state'
/etc/init.d/tasks task_status openclawmgr 2>/dev/null | lua -e 'local j=require("luci.jsonc"); local x=j.parse(io.read("*a")) or {}; print(j.stringify({running=x.running,pid=x.pid,exit_code=x.exit_code,data_exit=x.data and x.data.exit_code}))' || true
printf '%s\n' '== recent task log'
tail -n 28 /var/log/tasks/openclawmgr.log 2>/dev/null || true
printf '%s\n' '== node execution'
base="$(uci -q get openclawmgr.main.base_dir)"
for node in "$base"/.install.*/candidate/node/bin/node "$base"/node/bin/node; do
 if [ -x "$node" ]; then "$node" -p 'JSON.stringify({node:process.versions.node,arch:process.arch,sqlite:process.versions.sqlite})'; break; fi
done
printf '%s\n' '== state'
for p in "$base"/.install.*/phase; do [ ! -f "$p" ] || cat "$p"; done
df -Pk "$base"
