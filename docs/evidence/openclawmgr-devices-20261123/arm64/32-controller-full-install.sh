set -eu
test_root='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123'
ACCEPTANCE_OP=install CANDIDATE_CONTROLLER="$test_root/assets/candidate-controller.lua" lua "$test_root/assets/controller-call.lua"
