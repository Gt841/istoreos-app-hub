#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime-live' 'node-24.21.0-aarch64-glibc-upstream1-npm11.19.0-glibc-2.39-ubuntu8-gcc12-legal1-r1-aarch64-c5381d67a2fc8268ee973d2262f592fd3e53262d5950bd8a9c65bdd766346544' "$@"
