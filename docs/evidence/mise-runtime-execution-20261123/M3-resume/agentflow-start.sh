#!/bin/sh
. /mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/M3/legacy-mise.sh || exit 1
if ! istore_runtime_env; then exit 1; fi
cd /mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/M3/agentflow-compat-resume || exit 1
printf '%s\n' "$$" > candidate.pid
export AGENT_FLOW_DATA="$PWD/data" AGENT_FLOW_HOST=127.0.0.1 AGENT_FLOW_PORT=19003
exec /usr/sbin/agentflow
