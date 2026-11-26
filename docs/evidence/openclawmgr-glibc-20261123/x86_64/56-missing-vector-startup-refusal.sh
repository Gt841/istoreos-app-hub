set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
vec="$("$base/node/bin/node" -e 'console.log(require("node:module").createRequire(process.argv[1])("sqlite-vec").getLoadablePath())' "$base/global/lib/node_modules/openclaw/package.json")"
case "$vec" in "$base"/*) ;; *) exit 1 ;; esac
disabled="$vec.acceptance-disabled"
test ! -e "$disabled"
before="$(sha256sum "$vec")"
restore_extension() {
 if [ -f "$disabled" ]; then mv "$disabled" "$vec"; fi
 /etc/init.d/openclawmgr start >/dev/null 2>&1 || true
}
trap restore_extension EXIT
trap 'exit 1' HUP INT TERM
/etc/init.d/openclawmgr stop || true
mv "$vec" "$disabled"
rc=0
/etc/init.d/openclawmgr start > "$root/logs/vec-disabled-start.log" 2>&1 || rc=$?
printf 'init_wrapper_exit=%s\n' "$rc"
running="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' 2>/dev/null || true)"
test "$running" != true
grep -E 'Error loading|sqlite|vec|Native' "$root/logs/vec-disabled-start.log" | tail -n 4 || true
printf '%s\n' 'missing sqlite-vec: Gateway refused to start'
mv "$disabled" "$vec"
test "$(sha256sum "$vec")" = "$before"
/etc/init.d/openclawmgr start
trap - EXIT HUP INT TERM
printf '%s\n' 'original extension bytes restored; service start requested'
