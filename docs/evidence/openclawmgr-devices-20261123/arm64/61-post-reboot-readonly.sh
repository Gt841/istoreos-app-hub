set -u
printf '%s\n' '== time and boot'
date -u '+%Y-%m-%dT%H:%M:%SZ'
uptime
cat /proc/sys/kernel/random/boot_id
printf '%s\n' '== resources'
free -m
df -h /
printf '%s\n' '== reboot evidence'
ls /sys/fs/pstore 2>/dev/null || true
dmesg | grep -Ei 'panic|watchdog|out of memory|oom-kill|reset|reboot|thermal|voltage|power' | tail -n 25 || true
printf '%s\n' '== recent relevant logs'
logread | grep -Ei 'panic|watchdog|out of memory|oom-kill|reset|reboot|thermal|voltage|power' | tail -n 25 || true
