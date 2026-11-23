set -u
test_root='/mnt/nvme0n1-1/Configs/openclawmgr-acceptance-20261123'
base='/mnt/nvme0n1-1/OpenClawMgr-acceptance-20261123'
for mode in default no-maglev; do
 mkdir -p "$test_root/pack-ab/$mode"
 flags=''
 [ "$mode" != no-maglev ] || flags=--no-maglev
 started="$(date +%s)"
 NODE_OPTIONS="$flags" HOME="$test_root/pack-ab/$mode/home" npm_config_cache="$base/npm-cache" npm_config_update_notifier=false PATH="$test_root/tools-node/bin:/usr/sbin:/usr/bin:/sbin:/bin" timeout -k 2 20 ks-cli npm pack openclaw@2026.3.28 --offline --ignore-scripts --json --pack-destination "$test_root/pack-ab/$mode" </dev/null > "$test_root/pack-ab/$mode/result.json" 2> "$test_root/pack-ab/$mode/stderr.log"
 rc=$?
 printf 'mode=%s rc=%s elapsed=%s\n' "$mode" "$rc" "$(($(date +%s) - started))"
 wc -c "$test_root/pack-ab/$mode/result.json"
 tail -n 4 "$test_root/pack-ab/$mode/stderr.log"
 for p in /proc/[0-9]*/exe; do
  exe="$(readlink "$p" 2>/dev/null || true)"
  case "$exe" in "$test_root/tools-node/bin/node"*) pid="${p#/proc/}"; pid="${pid%/exe}"; kill -KILL "$pid" 2>/dev/null || true ;; esac
 done
done
