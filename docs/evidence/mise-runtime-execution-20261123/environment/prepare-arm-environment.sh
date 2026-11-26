set -eu
base=/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123
[ -d /mnt/nvme0n1-1 ]
awk '$2=="/mnt/nvme0n1-1"&&$3=="ext4"{ok=1}END{exit !ok}' /proc/mounts
mkdir -p "$base/baseline" "$base/Runtime" "$base/packages";chmod 700 "$base" "$base/baseline" "$base/packages";chmod 755 "$base/Runtime"
[ -z "$(uci changes fstab)" ]
cp -p /etc/config/fstab "$base/baseline/fstab.before"
sha256sum /usr/sbin/iStoreEnhance /usr/bin/ks-cli /usr/sbin/agentflow /etc/config/mise /lib/functions/mise.sh > "$base/baseline/protected.sha256"
[ "$(block info /dev/sda2 | sed -n 's/.* UUID="\([^"]*\)".*/\1/p')" = 46d83bcb-66a09746-c6d8e97f-c3841042 ]
uci set fstab.mise_ignore_usb_x86=mount
uci set fstab.mise_ignore_usb_x86.uuid=46d83bcb-66a09746-c6d8e97f-c3841042
uci set fstab.mise_ignore_usb_x86.target=/mnt/usb8-2
uci set fstab.mise_ignore_usb_x86.fstype=squashfs
uci set fstab.mise_ignore_usb_x86.enabled=0
uci commit fstab
before="$(dmesg | grep -c 'SQUASHFS error' || true)"
DEVNAME=sda2 ACTION=add /usr/libexec/blockmount.sh
! awk '$1=="/dev/sda2"{ok=1}END{exit !ok}' /proc/mounts
after="$(dmesg | grep -c 'SQUASHFS error' || true)"
[ "$before" = "$after" ]
printf 'squashfs-errors-before=%s after=%s\n' "$before" "$after"
probe="$base/.probe"
mkdir "$probe"
printf '#!/bin/sh\nprintf "arm-filesystem-exec-ok\\n"\n' > "$probe/run"
chmod 700 "$probe/run";"$probe/run"
rm "$probe/run";rmdir "$probe"
sha256sum -c "$base/baseline/protected.sha256"
pidof iStoreEnhance agentflow
df -kP "$base"
stat -f -c 'inodes=%c free_inodes=%d' "$base"
uci show fstab.mise_ignore_usb_x86
