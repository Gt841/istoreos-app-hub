set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
while IFS= read -r path; do test ! -e "/$path" && test ! -L "/$path"; done < "$root/system-backup/absent"
! id openclawmgr >/dev/null 2>&1
test ! -d /tmp/openclawmgr-installer.lock
for link in /etc/rc.d/*openclawmgr; do test ! -e "$link" && test ! -L "$link"; done
if netstat -lnt 2>/dev/null | grep ':19189 '; then exit 1; fi
sha256sum -c "$root/system-backup/protected.sha256"
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running'

printf '%s\n' 'restoration verified'
uptime
cat /proc/sys/kernel/random/boot_id
