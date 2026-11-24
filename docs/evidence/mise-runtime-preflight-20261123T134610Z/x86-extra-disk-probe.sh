printf '[sdd-identity]\n'
for p in /sys/block/sdd/size /sys/block/sdd/ro /sys/block/sdd/device/model; do [ ! -r "$p" ] || { printf '%s=' "$p"; cat "$p"; }; done
printf '[sdd-partitions]\n'
awk 'NR<=2 || /sdd/' /proc/partitions
printf '[sdd-holders]\n'
ls -l /sys/block/sdd/holders
printf '[sdd-mounted]\n'
awk '$1 ~ /sdd/ {print}' /proc/mounts
printf '[sdd-signatures]\n'
block info /dev/sdd /dev/sdd1 2>/dev/null || true
blkid /dev/sdd /dev/sdd1 2>/dev/null || true
printf '[sdd-layout]\n'
fdisk -l /dev/sdd
