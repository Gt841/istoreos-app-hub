set -u
printf '%s\n' '== required UCI fields'
uci -q get openclawmgr.main
uci -q get openclawmgr.main.base_dir
uci -q get openclawmgr.main.enabled
printf '%s\n' '== safe trace identifiers'
sh -x /usr/libexec/istorec/openclawmgr.sh recover_install 2>&1 | sed -n 's/^+ \([a-zA-Z_][a-zA-Z_0-9]*\).*/\1/p' | tail -n 45
