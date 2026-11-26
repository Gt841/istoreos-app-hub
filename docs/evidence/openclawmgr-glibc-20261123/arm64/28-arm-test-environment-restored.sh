set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
base="$(uci -q get openclawmgr.main.base_dir)"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
test "$base" = /mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123
test ! -d /tmp/openclawmgr-installer.lock
cp "$base/log/installer.log" "$root/logs/interrupted-and-recovered-installer.log"
/etc/init.d/openclawmgr stop || true
/etc/init.d/openclawmgr disable || true
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
sha256sum -c "$root/system-backup/protected.sha256"
test ! -e "$root/recovered-probe-runtime"
mv "$base" "$root/recovered-probe-runtime"
chown -hR root:root "$root/recovered-probe-runtime"
while IFS= read -r path; do
 case "$path" in etc/config/openclawmgr|etc/init.d/openclawmgr|usr/libexec/istorec/openclawmgr.sh|usr/share/openclawmgr|usr/share/openclawmgr-glibc) rm -rf "/$path" ;; *) exit 1 ;; esac
done < "$root/system-backup/absent"
test "$(id -u openclawmgr)" = "$(cat "$root/system-backup/user.created")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
printf '%s\n' 'ARM test files/account removed; KSpeeder preserved; vector probe and recovery evidence retained privately'
