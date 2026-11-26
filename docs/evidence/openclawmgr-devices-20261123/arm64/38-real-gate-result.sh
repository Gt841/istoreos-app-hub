set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="${base%/*}/Configs/openclawmgr-acceptance-20261123"
cp /var/log/tasks/openclawmgr.log "$root/logs/05-native-and-health-gate.log"
tail -n 45 /var/log/tasks/openclawmgr.log
