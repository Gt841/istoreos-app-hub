set -eu
test "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/owner")" = openclawmgr-device-acceptance-20261123
base="$(uci -q get openclawmgr.main.base_dir)"
test "$base" = /mnt/vio4-0/OpenClawMgr-acceptance-20261123
test "$(uci -q get 'istoreenhance.@istoreenhance[0].adminport')" = 55003
test ! -d /tmp/openclawmgr-installer.lock
/etc/init.d/openclawmgr stop
/etc/init.d/openclawmgr disable
/etc/init.d/istoreenhance stop
/etc/init.d/istoreenhance disable
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
test "$(ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running' 2>/dev/null || true)" != true
cp "$base/log/installer.log" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/12-final-installer.log"
test ! -e "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
mv "$base" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
chown -hR root:root "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
rm -f /etc/config/openclawmgr /etc/init.d/openclawmgr /usr/libexec/istorec/openclawmgr.sh /usr/bin/ks-cli /usr/sbin/iStoreEnhance /etc/config/istoreenhance /etc/init.d/istoreenhance
rm -rf /usr/share/openclawmgr
test "$(id -u openclawmgr)" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/user.created")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
printf '%s\n' 'x86 test services/configs/binaries/account removed; private runtime evidence retained'
for name in openclawmgr istoreenhance; do ls /etc/rc.d/*"$name" 2>/dev/null || true; done
printf '%s\n' '== uptime'
uptime
