#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123/Runtime-live' 'zig-0.17.1-aarch64-native-upstream1-bd248d9f17853dc2352b545c82c15ee9ec396d69082629a028a4a78c2fb0b37a' "$@"
