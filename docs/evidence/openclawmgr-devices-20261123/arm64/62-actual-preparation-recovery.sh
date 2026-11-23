set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do [ ! -d "$txn" ] || { basename "$txn"; cat "$txn/phase"; }; done
/usr/libexec/istorec/openclawmgr.sh recover_install
test ! -d /tmp/openclawmgr-installer.lock
for txn in "$base"/.install.*; do [ ! -d "$txn" ]; done
printf '%s\n' 'preparation recovery passed'
