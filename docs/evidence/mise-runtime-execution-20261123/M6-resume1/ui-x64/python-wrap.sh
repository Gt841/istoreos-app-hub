#!/bin/sh
set -eu
umask 077
exec /usr/bin/lua '/usr/share/mise-runtime/execute.lua' '/mnt/mise-runtime/Runtime-live' 'python-3.13.18-x86_64-musl-20261110-e9f316056f3efb9bd18467f472377cce25eeca0a238be45dd02761ea27d3f49a' "$@"
