set -eu
test "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/owner")" = openclawmgr-device-acceptance-20261123
while IFS= read -r path; do
 test ! -e "/$path" && test ! -L "/$path"
done < "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/absent"
! id openclawmgr >/dev/null 2>&1
test ! -d /tmp/openclawmgr-installer.lock
for link in /etc/rc.d/*openclawmgr; do test ! -e "$link" && test ! -L "$link"; done
printf '%s\n' 'baseline absence/account/lock/boot-link checks passed'

opkg list-installed | grep -E '^(coreutils-timeout|git |git-http )'
printf '%s\n' '== test port listeners (must be empty)'
if netstat -lnt 2>/dev/null | grep -E ':(19189|55443|55003)[[:space:]]'; then exit 1; fi
uptime
