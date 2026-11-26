set -u
printf '%s\n' '== boot stability'
date -u '+%Y-%m-%dT%H:%M:%SZ'
uptime
cat /proc/sys/kernel/random/boot_id
printf '%s\n' '== watchdog boot status'
for file in /sys/class/watchdog/watchdog*/bootstatus /sys/class/watchdog/watchdog*/identity; do
 [ ! -r "$file" ] || { printf '%s=' "$file"; cat "$file"; }
done
printf '%s\n' '== kernel panic policy'
cat /proc/sys/kernel/panic
printf '%s\n' '== kernel temperature readings'
for file in /sys/class/thermal/thermal_zone*/temp; do [ ! -r "$file" ] || { printf '%s=' "$file"; cat "$file"; }; done
