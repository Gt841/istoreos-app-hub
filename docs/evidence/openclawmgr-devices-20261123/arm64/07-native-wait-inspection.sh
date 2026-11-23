set -eu
test_root='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123'
base='/mnt/nvme0n1-1/OpenClawMgr-acceptance-20261123'
printf '%s\n' '== owned residual Node processes'
for p in /proc/[0-9]*/exe; do
 exe="$(readlink "$p" 2>/dev/null || true)"
 case "$exe" in "$base"/.install.*/candidate/node/bin/node*) ;; *) continue ;; esac
 pid="${p#/proc/}"; pid="${pid%/exe}"
 printf 'owned_pid=%s comm=' "$pid"; cat "/proc/$pid/comm" || true
 printf 'wchan='; cat "/proc/$pid/wchan" || true; printf '\n'
 kill -KILL "$pid" 2>/dev/null || true
done
mkdir -p "$test_root/tools-node" "$test_root/pack-ab"
arch='arm64'
tar -xJf "$base/npm-cache/node-24.22.1-$arch-musl.tar.xz" -C "$test_root/tools-node" --strip-components=1 --no-same-owner
printf '%s\n' '== V8 candidate flags'
"$test_root/tools-node/bin/node" --no-maglev --version
