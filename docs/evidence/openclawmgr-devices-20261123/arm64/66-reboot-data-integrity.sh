set -u
base="$(uci -q get openclawmgr.main.base_dir)"
printf '%s\n' '== data snapshot sizes'
ls -l "$base/data/.openclaw/openclaw.json"
for release in "$base"/backups/*; do ls -l "$release/data.tar"; done
printf '%s\n' '== current boot errors'
dmesg | grep -Ei 'SQUASHFS|EXT4-fs.*(error|recovery)|I/O error|panic|watchdog' | tail -n 15 || true
