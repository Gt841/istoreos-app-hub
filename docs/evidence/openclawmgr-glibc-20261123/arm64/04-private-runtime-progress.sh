set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf 'task='; /etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
printf '%s\n' '== phase tail'; tail -n 8 /var/log/tasks/openclawmgr.log
for txn in "$base"/.install.*; do
 if [ -x "$txn/candidate/node/bin/node" ]; then
 timeout -k 2 15 "$txn/candidate/node/bin/node" -p 'JSON.stringify({arch:process.arch,glibc:process.report.getReport().header.glibcVersionRuntime,execPath:process.execPath})' || true
 fi
done
