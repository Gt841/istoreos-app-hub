set -u
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
printf '%s\n' '== service state'
ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.running' -e '@.openclawmgr.instances.gateway.pid'
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
if [ -n "$pid" ]; then sed -n '/^Name:/p;/^State:/p;/^Uid:/p;/^VmRSS:/p' "/proc/$pid/status"; fi
printf '%s\n' '== redacted startup diagnostics'
logread -e openclaw > "$root/logs/gateway-startup-private.log"
"$base/node/bin/node" -e 'const fs=require("node:fs");const cfg=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));let text=fs.readFileSync(process.argv[2],"utf8");if(cfg.gateway?.auth?.token)text=text.split(cfg.gateway.auth.token).join("[REDACTED]");console.log(text.split("\n").filter(s=>/error|failed|EACCES|listening|startup|crash|closed/i.test(s)).slice(-20).join("\n"));' "$base/data/.openclaw/openclaw.json" "$root/logs/gateway-startup-private.log"
