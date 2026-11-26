set -u
base="$(uci -q get openclawmgr.main.base_dir)"
uptime
cat /proc/sys/kernel/random/boot_id
printf '%s\n' '== transaction phases'
for txn in "$base"/.install.*; do [ ! -d "$txn" ] || { basename "$txn"; cat "$txn/phase"; }; done
printf '%s\n' '== memory panic policy'
cat /proc/sys/vm/panic_on_oom /proc/sys/kernel/panic
printf '%s\n' '== current reboot errors'
dmesg | grep -Ei 'panic|oom-kill|out of memory|SQUASHFS error|I/O error' | tail -n 12 || true
printf '%s\n' '== data and receipt sizes'
ls -l "$base/current/receipt.json" "$base/data/.openclaw/openclaw.json" 2>/dev/null || true
