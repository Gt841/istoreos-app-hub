set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
before_current="$(readlink "$base/current")"
before_config="$(sha256sum "$base/data/.openclaw/openclaw.json")"
rc=0
/usr/libexec/istorec/openclawmgr.sh recover_install || rc=$?
printf 'recovery_exit=%s\n' "$rc"
test "$rc" -ne 0
test "$(readlink "$base/current")" = "$before_current"
test "$(sha256sum "$base/data/.openclaw/openclaw.json")" = "$before_config"
test -d /tmp/openclawmgr-installer.lock
printf '%s\n' 'invalid snapshot refused; current, data and journal preserved'
