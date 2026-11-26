set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
rc=0
su -s /bin/sh -c "cd $base/data && HOME=$base/data OPENCLAW_HOME=$base/data OPENCLAW_STATE_DIR=$base/data/.openclaw OPENCLAW_CONFIG_PATH=$base/data/.openclaw/openclaw.json PATH=$base/node/bin:$base/global/bin:/usr/sbin:/usr/bin:/sbin:/bin timeout -k 2 40 $base/node/bin/node $base/global/lib/node_modules/openclaw/openclaw.mjs memory status --json" openclawmgr > "$root/logs/memory-status.json" 2> "$root/logs/memory-status.stderr" || rc=$?
printf 'memory_status_exit=%s\n' "$rc"
"$base/node/bin/node" -e 'const fs=require("node:fs");try{const rows=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(JSON.stringify(rows.map(r=>({agentId:r.agentId,backend:r.status?.backend,provider:r.status?.provider,vector:r.status?.vector}))));}catch(e){console.log("Status output was not JSON; raw output retained privately");}' "$root/logs/memory-status.json"
