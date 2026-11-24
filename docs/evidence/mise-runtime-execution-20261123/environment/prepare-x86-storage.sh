set -eu
[ "$(cat /sys/block/sdd/size)" = 134217728 ]
[ -z "$(ls -A /sys/block/sdd/holders)" ]
! awk '$1 ~ /sdd/{found=1}END{exit !found}' /proc/mounts
[ -z "$(block info /dev/sdd 2>/dev/null)" ]
[ ! -e /mnt/mise-runtime ] || [ -z "$(ls -A /mnt/mise-runtime)" ]
[ -z "$(uci changes fstab)" ]
backup=/mnt/vio4-0/Configs/mise-environment-prep-20261123
mkdir -p "$backup";chmod 700 "$backup"
cp -p /etc/config/fstab "$backup/fstab.before"
mkfs.ext4 -L mise-runtime -m 1 /dev/sdd
mkdir -p /mnt/mise-runtime
mount -t ext4 -o rw,noatime /dev/sdd /mnt/mise-runtime
uuid="$(block info /dev/sdd | sed -n 's/.* UUID="\([^"]*\)".*/\1/p')"
[ -n "$uuid" ]
uci set fstab.mise_runtime_test=mount
uci set "fstab.mise_runtime_test.uuid=$uuid"
uci set fstab.mise_runtime_test.target=/mnt/mise-runtime
uci set fstab.mise_runtime_test.fstype=ext4
uci set fstab.mise_runtime_test.options=rw,noatime
uci set fstab.mise_runtime_test.enabled=1
uci commit fstab
probe=/mnt/mise-runtime/.mise-preparation-probe
mkdir "$probe"
printf '#!/bin/sh\nprintf "mise-filesystem-exec-ok\\n"\n' > "$probe/exec"
chmod 700 "$probe/exec"
"$probe/exec"
printf 'persistent-before-remount\n' > "$probe/persist"
sync
umount /mnt/mise-runtime
mount -t ext4 -o rw,noatime /dev/sdd /mnt/mise-runtime
[ "$(cat "$probe/persist")" = persistent-before-remount ]
"$probe/exec"
rm "$probe/exec" "$probe/persist";rmdir "$probe"
mkdir -p /mnt/mise-runtime/Runtime /mnt/mise-runtime/acceptance /mnt/mise-runtime/packages
chmod 755 /mnt/mise-runtime /mnt/mise-runtime/Runtime
chmod 700 /mnt/mise-runtime/acceptance /mnt/mise-runtime/packages
printf '[final]\n';df -kP /mnt/mise-runtime
stat -f -c 'inodes=%c free_inodes=%d' /mnt/mise-runtime
uci -q show fstab.mise_runtime_test
