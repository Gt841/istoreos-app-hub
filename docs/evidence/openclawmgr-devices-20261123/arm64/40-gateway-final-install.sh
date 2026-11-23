set -eu
chown root:root /usr/libexec/istorec/openclawmgr.sh /usr/share/openclawmgr/install-runtime.sh /usr/share/openclawmgr/runtime-check.cjs
chmod go-w /usr/libexec/istorec/openclawmgr.sh /usr/share/openclawmgr/install-runtime.sh /usr/share/openclawmgr/runtime-check.cjs
ACCEPTANCE_OP=install CANDIDATE_CONTROLLER="/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/candidate-controller.lua" lua "/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123/assets/controller-call.lua"
