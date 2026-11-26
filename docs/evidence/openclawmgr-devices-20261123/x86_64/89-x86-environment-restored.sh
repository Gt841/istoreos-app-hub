set -eu
test "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/owner")" = openclawmgr-device-acceptance-20261123
base="$(uci -q get openclawmgr.main.base_dir)"
test "$base" = /mnt/vio4-0/OpenClawMgr-acceptance-20261123
test "$(uci -q get 'istoreenhance.@istoreenhance[0].adminport')" = 55003
test ! -d /tmp/openclawmgr-installer.lock
printf '%s\n' 'guards passed'
/etc/init.d/openclawmgr stop || true
/etc/init.d/openclawmgr disable || true
/etc/init.d/istoreenhance stop || true
/etc/init.d/istoreenhance disable || true
sleep 2
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
test "$(ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running' 2>/dev/null || true)" != true
printf '%s\n' 'test services stopped'
cp "$base/log/installer.log" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/logs/12-final-installer.log"
test ! -e "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
mv "$base" "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
chown -hR root:root "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
printf '%s\n' 'runtime evidence secured'
rm -f /etc/config/openclawmgr /etc/init.d/openclawmgr /usr/libexec/istorec/openclawmgr.sh /usr/bin/ks-cli /usr/sbin/iStoreEnhance /etc/config/istoreenhance /etc/init.d/istoreenhance
rm -rf /usr/share/openclawmgr
test "$(id -u openclawmgr)" = "$(cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/user.created")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
printf '%s\n' 'x86 temporary files/account removed'
for name in openclawmgr istoreenhance; do ls /etc/rc.d/*"$name" 2>/dev/null || true; done
uptime
