#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime-live' 'go-1.27.4-aarch64-native-upstream1-9aaf949ea1723fff27a251ae6849cab71a17a9fdf03252dd000eb8545390ca29' "$@"
