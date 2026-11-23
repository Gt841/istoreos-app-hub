set -eu
root=/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123
echo '== preserved probe content'
ls -la "$root/recovered-probe-runtime"
ls -la "$root/recovered-probe-runtime/global/lib/node_modules" 2>/dev/null || true
echo '== service logs include successful listening before rollback'
logread | grep -E 'node\[17546\].*(listening on|SIGTERM|shutting down)' || true
echo '== protection'
(cd / && sha256sum -c "$root/system-backup/protected.sha256")
