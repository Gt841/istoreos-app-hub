set -eu
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
test ! -d /tmp/openclawmgr-installer.lock
tar -xf "$root/assets/backend-final.tar" -C /
/etc/init.d/tasks task_add openclawmgr '/usr/libexec/istorec/openclawmgr.sh upgrade'
printf '%s\n' 'second glibc upgrade submitted with warm cache and final startup gate'
