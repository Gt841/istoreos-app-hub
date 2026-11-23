set -eu
root=/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123
base="$(uci -q get openclawmgr.main.base_dir)"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
test "$base" = /mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123
test ! -d /tmp/openclawmgr-installer.lock
test -z "$(find "$base" -maxdepth 1 -name '.install.*' -print)"
cp "$base/log/installer.log" "$root/logs/final-installer.log"
cp /var/log/tasks/openclawmgr.log "$root/logs/final-glibc-install.log"
/etc/init.d/openclawmgr stop || true
/etc/init.d/openclawmgr disable || true
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
test ! -e "$root/final-rolled-back-runtime"
mv "$base" "$root/final-rolled-back-runtime"
chown -hR root:root "$root/final-rolled-back-runtime"
while IFS= read -r path; do
 case "$path" in etc/config/openclawmgr|etc/init.d/openclawmgr|usr/libexec/istorec/openclawmgr.sh|usr/share/openclawmgr|usr/share/openclawmgr-glibc) rm -rf "/$path" ;; *) exit 1 ;; esac
done < "$root/system-backup/absent"
test "$(id -u openclawmgr)" = "$(cat "$root/system-backup/user.created-final")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
/etc/init.d/tasks task_del openclawmgr >/dev/null 2>&1 || true
(cd / && sha256sum -c "$root/system-backup/protected.sha256")
echo 'ARM final test baseline restored; rollback logs/runtime retained privately'
