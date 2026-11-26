#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime-live' 'python-3.13.18-aarch64-musl-20261110-54e77ae2454aafda2b139fa1a20aecd97542df5fe7e8ff71bd35cfa45b917728' "$@"
