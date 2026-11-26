printf '[time]\n'
date -u
cat /proc/sys/kernel/random/boot_id
printf '[kernel-alerts]\n'
dmesg 2>/dev/null | awk '/SQUASHFS.*[Ee]rror|I\/O error|Buffer I\/O|EXT4-fs error|Out of memory|oom-kill/{n++;if(n<=12)print}END{print "matched_lines=" n+0}'
printf '[physical-block-capacity]\n'
for f in /sys/block/sd*/size /sys/block/nvme*/size /sys/block/mmcblk*/size /sys/block/vd*/size; do [ -r "$f" ] || continue; printf '%s sectors=' "$f"; cat "$f"; done
printf '[load-and-memory]\n'
uptime
awk '/MemAvailable:|SwapTotal:/{print}' /proc/meminfo
