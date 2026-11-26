set -eu
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
base="/mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123"
test "$(cat "$root/owner")" = openclawmgr-glibc-device-acceptance-20261123
tar -xf "$root/assets/candidate-aarch64.tar" -C /
chmod 600 /etc/config/openclawmgr
cp "$root/assets/node-v24.22.1-linux-arm64.tar.xz" "$base/npm-cache/node-24.22.1-arm64-glibc.tar.xz"
uci set openclawmgr.main.enabled=1
uci set openclawmgr.main.base_dir="$base"
uci set openclawmgr.main.install_accelerated=1
uci set openclawmgr.main.port=19189
uci set openclawmgr.main.bind=loopback
uci commit openclawmgr

printf '%s\n' 'candidate deployed'
/etc/init.d/tasks task_add openclawmgr '/usr/libexec/istorec/openclawmgr.sh install'
printf '%s\n' 'real glibc install task submitted'
