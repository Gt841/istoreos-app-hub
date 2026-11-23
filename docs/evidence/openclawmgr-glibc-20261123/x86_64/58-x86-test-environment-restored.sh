set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
base="$(uci -q get openclawmgr.main.base_dir)"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
test "$base" = /mnt/vio4-0/OpenClawMgr-glibc-acceptance-20261123
test ! -d /tmp/openclawmgr-installer.lock
cp "$base/log/installer.log" "$root/logs/final-installer.log"
/etc/init.d/openclawmgr stop || true
/etc/init.d/openclawmgr disable || true
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
test ! -e "$root/completed-runtime"
mv "$base" "$root/completed-runtime"
chown -hR root:root "$root/completed-runtime"
while IFS= read -r path; do
 case "$path" in etc/config/openclawmgr|etc/init.d/openclawmgr|usr/libexec/istorec/openclawmgr.sh|usr/share/openclawmgr|usr/share/openclawmgr-glibc) rm -rf "/$path" ;; *) exit 1 ;; esac
done < "$root/system-backup/absent"
test "$(id -u openclawmgr)" = "$(cat "$root/system-backup/user.created")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
/etc/init.d/tasks task_del openclawmgr >/dev/null 2>&1 || true
printf '%s\n' 'x86 test service/account/system files restored to baseline; successful glibc runtime preserved privately'
