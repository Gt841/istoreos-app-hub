set -eu
test "$(cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/owner")" = openclawmgr-device-acceptance-20261123
while IFS= read -r path; do
 test ! -e "/$path" && test ! -L "/$path"
done < "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/absent"
! id openclawmgr >/dev/null 2>&1
test ! -d /tmp/openclawmgr-installer.lock
for link in /etc/rc.d/*openclawmgr; do test ! -e "$link" && test ! -L "$link"; done
printf '%s\n' 'baseline absence/account/lock/boot-link checks passed'
sha256sum -c "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/protected.sha256"
ks-cli version
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running'

opkg list-installed | grep -E '^(coreutils-timeout|git |git-http )'
printf '%s\n' '== test port listeners (must be empty)'
if netstat -lnt 2>/dev/null | grep -E ':(19189|55443|55003)[[:space:]]'; then exit 1; fi
uptime
