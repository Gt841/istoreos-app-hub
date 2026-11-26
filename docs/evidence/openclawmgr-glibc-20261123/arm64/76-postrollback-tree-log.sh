set -eu
base=/mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123
root=/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123
echo '== preserved tree'
ls -la "$base"
ls -la "$base/releases" "$root"
echo '== filtered service log'
logread | grep -E '17546|openclaw|node.real|ld.so|procd.*(crash|exit)|GLIBC|EACCES|MODULE_NOT_FOUND' | sed -E 's/(token[=: ]+)[^ ,"]+/\1[REDACTED]/g' | tail -n 70 || true
echo '== archived diagnostic logs'
ls -l "$root/logs"
cp /var/log/tasks/openclawmgr.log "$root/logs/final-glibc-install.log"
cp "$base/log/installer.log" "$root/logs/final-installer.log"
