set -eu
printf '%s\n' '== backup inventory'; ls -la "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup"
printf '%s\n' '== originally absent'; cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/absent"
printf '%s\n' '== test account'; cat "/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123/system-backup/user.created"
