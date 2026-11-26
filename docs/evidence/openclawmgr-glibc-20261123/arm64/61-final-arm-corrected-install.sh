set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
base="/mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
test ! -e "$base"
while IFS= read -r path; do test ! -e "/$path" && test ! -L "/$path"; done < "$root/system-backup/absent"
! id openclawmgr >/dev/null 2>&1
groupadd -r openclawmgr
useradd -r -M -g openclawmgr -s /bin/false openclawmgr
id -u openclawmgr > "$root/system-backup/user.created-final"
mkdir -p "$base/npm-cache"
cp -a "$root/recovered-probe-runtime/npm-cache/." "$base/npm-cache/"
chmod 700 "$base/npm-cache"
tar -xf "$root/assets/candidate-aarch64.tar" -C /
tar -xf "$root/assets/backend-final-libc.tar" -C /
chmod 600 /etc/config/openclawmgr
cp "$root/assets/node-v24.22.1-linux-arm64.tar.xz" "$base/npm-cache/node-24.22.1-arm64-glibc.tar.xz"
uci set openclawmgr.main.enabled=1
uci set openclawmgr.main.base_dir="$base"
uci set openclawmgr.main.install_accelerated=1
uci set openclawmgr.main.port=19189
uci set openclawmgr.main.bind=loopback
uci commit openclawmgr
cat /proc/sys/kernel/random/boot_id > "$root/assets/boot-before-final"
/etc/init.d/tasks task_add openclawmgr '/usr/libexec/istorec/openclawmgr.sh install'
printf '%s\n' 'ARM final corrected candidate submitted once with explicit glibc optional dependency selection'
