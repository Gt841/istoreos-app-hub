set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
cat > "$base/probe_modules/probe.cjs" <<'JS'
const { DatabaseSync } = require('node:sqlite');
const db = new DatabaseSync(':memory:', {allowExtension:true});
require('sqlite-vec').load(db);
db.exec('CREATE VIRTUAL TABLE vectors USING vec0(embedding float[2])');
const insert = db.prepare('INSERT INTO vectors(rowid, embedding) VALUES (?, ?)');
insert.run(1n, '[1,0]'); insert.run(2n, '[0,1]');
const hit = db.prepare('SELECT rowid,distance FROM vectors WHERE embedding MATCH ? AND k=1').get('[0.9,0.1]');
if(hit.rowid!==1 || !Number.isFinite(hit.distance)) throw Error('Vector query failed');
console.log(JSON.stringify({uid:process.getuid(),arch:process.arch,glibc:process.report.getReport().header.glibcVersionRuntime,vec:db.prepare('SELECT vec_version() v').get().v,nearestNeighbor:hit}));
JS
su -s /bin/sh -c "$base/probe-node/bin/node $base/probe_modules/probe.cjs" openclawmgr
printf 'boot='; cat /proc/sys/kernel/random/boot_id
