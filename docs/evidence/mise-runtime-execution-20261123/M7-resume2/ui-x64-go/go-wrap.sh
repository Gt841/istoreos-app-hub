#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/mise-runtime/Runtime-live' 'go-1.27.4-x86_64-native-upstream1-51d304294ca856b1bd2349f1a4e5f6967fa34546b5fa82405d72cacfb75a56e1' "$@"
