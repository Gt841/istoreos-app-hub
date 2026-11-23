set -eu
test "$(cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/owner")" = openclawmgr-device-acceptance-20261123
base="$(uci -q get openclawmgr.main.base_dir)"
test "$base" = /mnt/nvme0n1-1/OpenClawMgr-acceptance-20261123
/etc/init.d/openclawmgr stop
/etc/init.d/openclawmgr disable
test "$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)" != true
cp "$base/log/installer.log" "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/logs/09-final-interrupted-installer.log"
test ! -e "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/interrupted-runtime"
mv "$base" "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/interrupted-runtime"
chown -hR root:root "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/interrupted-runtime"
# Only the CLI was replaced. Existing KSpeeder service/config/binary remain untouched.
tar -xf "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/files.tar" -C / usr/bin/ks-cli
sha256sum -c "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/protected.sha256"
rm -f /etc/config/openclawmgr /etc/init.d/openclawmgr /usr/libexec/istorec/openclawmgr.sh
rm -rf /usr/share/openclawmgr
if [ -d /tmp/openclawmgr-installer.lock ]; then mv /tmp/openclawmgr-installer.lock "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/final-recovery-lock"; fi
test "$(id -u openclawmgr)" = "$(cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/user.created")"
userdel openclawmgr
groupdel openclawmgr 2>/dev/null || true
printf '%s\n' 'ARM original protected files restored; test service/account removed; interrupted runtime preserved privately'
printf 'ks_cli='; ks-cli version
printf 'KSpeeder_running='
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running'
printf '%s\n' '== residual boot links'
ls /etc/rc.d/*openclawmgr 2>/dev/null || true
