set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
while IFS= read -r path; do test ! -e "/$path" && test ! -L "/$path"; done < "$root/system-backup/absent"
! id openclawmgr >/dev/null 2>&1
test ! -d /tmp/openclawmgr-installer.lock
for link in /etc/rc.d/*openclawmgr; do test ! -e "$link" && test ! -L "$link"; done
if netstat -lnt 2>/dev/null | grep ':19189 '; then exit 1; fi

printf '%s\n' 'restoration verified'
uptime
cat /proc/sys/kernel/random/boot_id
