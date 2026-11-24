#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/mise-runtime/Runtime-live' 'node-24.21.0-x86_64-glibc-upstream1-npm11.19.0-glibc-2.39-ubuntu8-gcc12-legal1-r1-x86_64-3c978e5d25a3a081a1b08f661b79fe92eb2c95f10b625b981a43b56b40eb4463' "$@"
