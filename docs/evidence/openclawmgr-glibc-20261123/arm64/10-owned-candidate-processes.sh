set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== owned candidate process state'
for file in /proc/[0-9]*/exe; do
 exe="$(readlink "$file" 2>/dev/null || true)"
 case "$exe" in "$base"/.install.*/*)
  pid="${file#/proc/}"; pid="${pid%/exe}"
  printf 'pid=%s executable=%s\n' "$pid" "$exe"
  sed -n '/^Name:/p;/^State:/p;/^VmRSS:/p' "/proc/$pid/status"
  sed 's/^.*) //' "/proc/$pid/stat" | awk '{print "cpu_ticks=" $12+$13}'
  sed -n '/^read_bytes:/p;/^write_bytes:/p' "/proc/$pid/io"
 ;; esac
done
printf '%s\n' '== filesystem activity'
df -h "$base"
