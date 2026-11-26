set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
base="/mnt/vio4-0/OpenClawMgr-glibc-acceptance-20261123"
test ! -e "$root"
test ! -e "$base"
for path in etc/config/openclawmgr etc/init.d/openclawmgr usr/libexec/istorec/openclawmgr.sh usr/share/openclawmgr usr/share/openclawmgr-glibc; do test ! -e "/$path" && test ! -L "/$path"; done
umask 077
mkdir -p "$root/system-backup" "$root/assets" "$root/logs"
printf '%s\n' openclawmgr-glibc-device-acceptance-20261123 > "$root/owner"
printf '%s\n' etc/config/openclawmgr etc/init.d/openclawmgr usr/libexec/istorec/openclawmgr.sh usr/share/openclawmgr usr/share/openclawmgr-glibc > "$root/system-backup/absent"
if [ -f /usr/bin/ks-cli ]; then sha256sum /usr/bin/ks-cli /usr/sbin/iStoreEnhance /etc/config/istoreenhance > "$root/system-backup/protected.sha256"; fi
! id openclawmgr >/dev/null 2>&1
groupadd -r openclawmgr
useradd -r -M -g openclawmgr -s /bin/false openclawmgr
id -u openclawmgr > "$root/system-backup/user.created"
umask 022
mkdir -p "$base/npm-cache"
old="/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/completed-runtime"
if [ -d "$old/npm-cache" ]; then cp -a "$old/npm-cache/." "$base/npm-cache/"; fi
chmod 700 "$base/npm-cache"
printf '%s\n' 'private baseline backup and test account/cache prepared'
