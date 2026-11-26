set -eu
printf '%s\n' '== protected backup archive'
tar -tf "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/files.tar"
printf '%s\n' '== original protected hashes'
cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/protected.sha256"
printf '%s\n' '== originally present'
cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/present"
printf '%s\n' '== originally absent'
cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/absent"
printf '%s\n' '== test account identity'
cat "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/system-backup/user.created"
