set -u
test_root='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123'
base='/mnt/vio4-0/OpenClawMgr-acceptance-20261123'
mkdir -p "$test_root/pack-repro"
for candidate in "$base"/.install.*/candidate/node; do [ ! -x "$candidate/bin/node" ] || node_dir="$candidate"; done
if [ -z "${node_dir:-}" ]; then echo 'candidate no longer exists'; tail -n 25 /var/log/tasks/openclawmgr.log; exit 1; fi
printf '%s\n' '== bounded standalone pack (same native cache)'
HOME="$test_root/pack-repro/home" npm_config_cache="$base/npm-cache" PATH="$node_dir/bin:/usr/sbin:/usr/bin:/sbin:/bin" timeout -k 2 25 ks-cli npm pack openclaw@2026.3.28 --ignore-scripts --json --pack-destination "$test_root/pack-repro" > "$test_root/pack-repro/result.json" 2> "$test_root/pack-repro/stderr.log"
rc=$?
printf 'pack_repro_rc=%s\n' "$rc"
ls -lh "$test_root/pack-repro/"*.tgz "$test_root/pack-repro/result.json" 2>/dev/null || true
tail -n 6 "$test_root/pack-repro/stderr.log" 2>/dev/null || true
