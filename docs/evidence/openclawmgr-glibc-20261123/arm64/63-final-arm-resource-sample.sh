set -u
base="$(uci -q get openclawmgr.main.base_dir)"
uptime
free -m
printf '%s\n' '== thermal sensors/trips'
for file in /sys/class/thermal/thermal_zone*/temp /sys/class/thermal/thermal_zone*/trip_point_*_temp /sys/class/thermal/thermal_zone*/trip_point_*_type; do
 [ ! -r "$file" ] || { printf '%s=' "$file"; cat "$file"; }
done
printf '%s\n' '== owned Node memory'
for file in /proc/[0-9]*/exe; do
 exe="$(readlink "$file" 2>/dev/null || true)"
 case "$exe" in "$base"/.install.*/*)
  pid="${file#/proc/}"; pid="${pid%/exe}"
  printf 'pid=%s\n' "$pid"
  sed -n '/^Name:/p;/^State:/p;/^VmRSS:/p' "/proc/$pid/status"
 ;; esac
done
