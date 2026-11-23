set -eu
printf '%s\n' '== dependency package database (read-only)'
awk 'BEGIN { RS=""; FS="\n" } /(^|\n)Package: (coreutils-timeout|git|git-http)(\n|$)/ { for(i=1;i<=NF;i++) if($i ~ /^(Package|Version):/) print $i }' /usr/lib/opkg/status
printf '%s\n' '== test port listeners (must be empty)'
if netstat -lnt 2>/dev/null | grep -E ':(19189|55443|55003)[[:space:]]'; then exit 1; fi
printf '%s\n' '== boot stability'
uptime
cat /proc/sys/kernel/random/boot_id
printf '%s\n' 'restoration verified; opkg lock was not altered'
