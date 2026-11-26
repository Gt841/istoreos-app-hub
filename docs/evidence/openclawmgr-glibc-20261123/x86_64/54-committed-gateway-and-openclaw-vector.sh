set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/vio4-0/Configs/openclawmgr-glibc-acceptance-20261123"
test "$(jsonfilter -i "$base/current/receipt.json" -e '@.nativeChecks.sqliteVec.available')" = true
test "$(jsonfilter -i "$base/current/receipt.json" -e '@.nativeChecks.sqliteVec.nearestNeighbor')" = true
test "$(jsonfilter -i "$base/current/receipt.json" -e '@.runtime.glibc')" = 2.39
printf '%s\n' '== committed receipt'
jsonfilter -i "$base/current/receipt.json" -e '@.version' -e '@.runtime' -e '@.nativeChecks'
printf '%s\n' '== previous runtime'
"$base/previous/node/bin/node" -p 'process.report.getReport().header.glibcVersionRuntime || "musl"'
printf '%s\n' '== actual gateway user'
pid="$(ubus call service list '{"name":"openclawmgr"}' | jsonfilter -e '@.openclawmgr.instances.gateway.pid')"
sed -n '/^Uid:/p' "/proc/$pid/status"
printf '%s\n' '== authenticated health'
token="$(jsonfilter -i "$base/data/.openclaw/openclaw.json" -e '@.gateway.auth.token')"
HOME="$base/data" OPENCLAW_HOME="$base/data" OPENCLAW_STATE_DIR="$base/data/.openclaw" OPENCLAW_CONFIG_PATH="$base/data/.openclaw/openclaw.json" "$base/node/bin/node" "$base/global/lib/node_modules/openclaw/openclaw.mjs" gateway health --url ws://127.0.0.1:19189 --token "$token"
cp "$base/current/receipt.json" "$root/logs/committed-receipt.json"
cp /var/log/tasks/openclawmgr.log "$root/logs/final-glibc-upgrade.log"
cat > "$base/data/openclaw-vector-check.mjs" <<'JS'
import { pathToFileURL } from 'node:url';
const storage = await import(pathToFileURL(process.argv[2]+'/dist/memory-core-host-engine-storage-C3DUzgCl.js'));
const {DatabaseSync}=storage.t();
const db=new DatabaseSync(':memory:',{allowExtension:true});
const result=await storage.n({db});
if(!result.ok) throw Error(result.error);
db.exec('CREATE VIRTUAL TABLE vectors USING vec0(embedding float[2])');
const insert=db.prepare('INSERT INTO vectors(rowid,embedding) VALUES (?,?)');
insert.run(1n,'[1,0]');insert.run(2n,'[0,1]');
const hit=db.prepare('SELECT rowid,distance FROM vectors WHERE embedding MATCH ? AND k=1').get('[0.9,0.1]');
if(hit.rowid!==1) throw Error('Nearest neighbor failed');
console.log(JSON.stringify({uid:process.getuid(),glibc:process.report.getReport().header.glibcVersionRuntime,openclawLoader:result.ok,vec:db.prepare('SELECT vec_version() v').get().v,hit}));
db.close();
JS
chown openclawmgr:openclawmgr "$base/data/openclaw-vector-check.mjs"
printf '%s\n' '== OpenClaw own loader under service UID'
su -s /bin/sh -c "cd $base/data && $base/node/bin/node $base/data/openclaw-vector-check.mjs $base/global/lib/node_modules/openclaw" openclawmgr
