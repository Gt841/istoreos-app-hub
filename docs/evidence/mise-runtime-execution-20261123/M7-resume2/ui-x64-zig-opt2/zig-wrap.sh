#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/mise-runtime/Runtime-live' 'zig-0.17.1-x86_64-native-upstream1-1bc9b21d287a4bcf62e8a36c3dc7781901d19ffe7ee3d199c4d9e12fbcae1c61' "$@"
