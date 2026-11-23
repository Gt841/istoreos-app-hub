set -eu
test_root='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123'
base='/mnt/nvme0n1-1/OpenClawMgr-acceptance-20261123'
for d in "$base"/.install.*; do
 [ -d "$d" ] || continue
 for p in "$d"/openclaw*.tgz "$d"/pack.json "$d"/metadata.json "$d"/resolved.json; do
  [ ! -f "$p" ] || cp "$p" "$test_root/assets/"
 done
done
owner="$(cat /tmp/openclawmgr-installer.lock/pid)"
timeout_pid=''
cli_pid=''
for s in /proc/[0-9]*/stat; do
 [ -r "$s" ] || continue
 [ "$(awk '{print $4}' "$s")" != "$owner" ] || timeout_pid="${s#/proc/}"
done
timeout_pid="${timeout_pid%/stat}"
[ -n "$timeout_pid" ]
for s in /proc/[0-9]*/stat; do
 [ -r "$s" ] || continue
 [ "$(awk '{print $4}' "$s")" != "$timeout_pid" ] || cli_pid="${s#/proc/}"
done
cli_pid="${cli_pid%/stat}"
[ -n "$cli_pid" ]
[ "$(cat /proc/$cli_pid/comm)" = ks-cli ]
printf 'capturing_test_cli_pid=%s\n' "$cli_pid"
kill -QUIT "$cli_pid"
sleep 3
cp /var/log/tasks/openclawmgr.log "$test_root/logs/02-pack-hang-stack.log"
tail -n 8 /var/log/tasks/openclawmgr.log
