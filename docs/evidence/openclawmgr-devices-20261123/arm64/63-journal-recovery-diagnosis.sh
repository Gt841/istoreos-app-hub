set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== runtime layout'
ls -ld "$base" "$base"/{releases,backups,data,log} 2>/dev/null || true
for name in current previous node global; do printf '%s=' "$name"; readlink "$base/$name" || true; done
for txn in "$base"/.install.*; do
 [ -d "$txn" ] || continue
 printf '%s\n' '== journal'
 ls -la "$txn"
 for name in phase release old-current old-previous legacy was-running; do printf '%s=' "$name"; cat "$txn/$name" 2>/dev/null || true; done
done
printf '%s\n' '== installer log'
tail -n 25 "$base/log/installer.log"
printf '%s\n' '== uptime'
uptime
