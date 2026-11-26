set -u
base="$(uci -q get openclawmgr.main.base_dir)"
for file in /proc/[0-9]*/exe; do
 exe="$(readlink "$file" 2>/dev/null || true)"
 case "$exe" in "$base"/.install.*/*)
  pid="${file#/proc/}"; pid="${pid%/exe}"
  printf 'pid=%s exe=%s\n' "$pid" "$exe"
  sed -n '/^Name:/p;/^State:/p;/^VmRSS:/p' "/proc/$pid/status"
  printf 'command='; tr '\000' ' ' < "/proc/$pid/cmdline"; printf '\n'
  printf 'wait='; cat "/proc/$pid/wchan" 2>/dev/null || true; printf '\n'
 ;; esac
done
for txn in "$base"/.install.*; do [ ! -d "$txn/candidate/global" ] || du -sk "$txn/candidate/global"; done
