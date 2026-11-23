set -u
printf '%s\n' '== cleanup guards'
cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/owner"
uci -q get openclawmgr.main.base_dir
uci -q get 'istoreenhance.@istoreenhance[0].adminport'
if [ -d /tmp/openclawmgr-installer.lock ]; then printf 'lock='; cat /tmp/openclawmgr-installer.lock/pid; fi
printf '%s\n' '== test init'
head -n 20 /etc/init.d/istoreenhance
printf '%s\n' '== backend task'
/etc/init.d/tasks task_status openclawmgr | jsonfilter -e '@.running' || true
