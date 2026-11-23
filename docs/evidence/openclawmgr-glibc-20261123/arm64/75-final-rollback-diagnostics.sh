set -eu
base=/mnt/nvme0n1-1/OpenClawMgr-glibc-acceptance-20261123
root=/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123
echo '== boot'
cat /proc/sys/kernel/random/boot_id
echo '== journal and runtime directories'
ls -la "$base"/runtime "$base"/.install* "$base"/log 2>/dev/null || true
echo '== gateway diagnostic filenames'
find "$base" /tmp/openclaw -maxdepth 4 -type f -name '*.log' 2>/dev/null || true
echo '== task tail'
tail -n 25 /var/log/tasks/openclawmgr.log
echo '== available memory'
free -m
