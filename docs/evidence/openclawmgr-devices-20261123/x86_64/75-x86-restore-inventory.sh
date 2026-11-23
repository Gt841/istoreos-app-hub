set -eu
printf '%s\n' '== originally present'; cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/present"
printf '%s\n' '== originally absent'; cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/absent"
printf '%s\n' '== test account'; cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/user.created"
printf '%s\n' '== current test services'
ubus call service list '{"name":"istoreenhance"}' | jsonfilter -e '@.istoreenhance.instances.*.running'
