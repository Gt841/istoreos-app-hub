set -u
printf '%s\n' '== bounded installer process tree'
pid="$(cat /tmp/openclawmgr-installer.lock/pid 2>/dev/null || true)"
walk() {
 local parent="$1" depth="$2" file child ppid
 [ "$depth" -lt 5 ] || return
 for file in /proc/[0-9]*/stat; do
  [ -r "$file" ] || continue
  ppid="$(awk '{print $4}' "$file" 2>/dev/null)"
  [ "$ppid" = "$parent" ] || continue
  child="${file#/proc/}"; child="${child%/stat}"
  printf '%s parent=%s state=' "$child" "$parent"
  awk '{print $3}' "$file" 2>/dev/null
  cat "/proc/$child/comm" 2>/dev/null
  walk "$child" "$((depth + 1))"
 done
}
[ -z "$pid" ] || walk "$pid" 0
printf '%s\n' '== task log'
tail -n 32 /var/log/tasks/openclawmgr.log 2>/dev/null || true
