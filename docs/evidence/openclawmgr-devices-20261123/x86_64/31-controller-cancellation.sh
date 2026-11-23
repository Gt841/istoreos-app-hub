set -eu
test_root='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123'
cp /var/log/tasks/openclawmgr.log "$test_root/logs/04-cache-refresh-before-cancel.log"
ACCEPTANCE_OP=status CANDIDATE_CONTROLLER="$test_root/assets/candidate-controller.lua" lua "$test_root/assets/controller-call.lua"
ACCEPTANCE_OP=cancel_install CANDIDATE_CONTROLLER="$test_root/assets/candidate-controller.lua" lua "$test_root/assets/controller-call.lua"
[ ! -e /tmp/openclawmgr-installer.lock ]
printf '%s\n' 'controller cancellation cleanup passed'
