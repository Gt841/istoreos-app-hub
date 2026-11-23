set -eu
node="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123/recovered-probe-runtime/probe-node"
"$node/glibc/ld.so" --library-path "$node/glibc" --list "$node/bin/node.real"
