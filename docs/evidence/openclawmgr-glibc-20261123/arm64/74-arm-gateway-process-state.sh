set -u
printf '%s\n' '== managed UID process states (no command arguments)'
for file in /proc/[0-9]*/status; do
 uid="$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' "$file" 2>/dev/null)"
 [ "$uid" = 999 ] || continue
 pid="${file#/proc/}"; pid="${pid%/status}"
 printf 'pid=%s\n' "$pid"
 sed -n '/^Name:/p;/^PPid:/p;/^State:/p;/^VmRSS:/p' "$file"
 printf 'cwd='; readlink "/proc/$pid/cwd" 2>/dev/null || true
done
printf '%s\n' '== local test port'
netstat -lnt 2>/dev/null | grep ':19189 ' || true
printf '%s\n' '== current task'
tail -n 10 /var/log/tasks/openclawmgr.log
