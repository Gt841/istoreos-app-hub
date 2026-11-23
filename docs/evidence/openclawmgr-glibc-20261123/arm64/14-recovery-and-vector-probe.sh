set -eu
base="$(uci -q get openclawmgr.main.base_dir)"
root="/mnt/nvme0n1-1/Configs/openclawmgr-glibc-acceptance-20261123"
mkdir -p "$root/journal-before-recovery"
for txn in "$base"/.install.*; do
 [ -d "$txn" ] || continue
 test "$(cat "$txn/phase")" = preparing
 for file in phase release old-current old-previous legacy was-running resolved.json; do
  [ ! -f "$txn/$file" ] || cp "$txn/$file" "$root/journal-before-recovery/$file"
 done
done
/usr/libexec/istorec/openclawmgr.sh recover_install
for txn in "$base"/.install.*; do test ! -d "$txn"; done
test ! -d /tmp/openclawmgr-installer.lock
printf '%s\n' 'reboot interrupted preparing transaction recovered with normal backend'
mkdir -p "$base/probe-node" "$base/probe_modules/node_modules/sqlite-vec" "$base/probe_modules/node_modules/sqlite-vec-linux-arm64"
printf '%s\n' 'dbabf7a1cbf947e6059ffad2c27b80041db97dea1e553b62afdee7f13fca336e  '"$root/assets/node-v24.22.1-linux-arm64.tar.xz" | sha256sum -c -
tar -xJf "$root/assets/node-v24.22.1-linux-arm64.tar.xz" -C "$base/probe-node" --strip-components=1 --no-same-owner
cp -a /usr/share/openclawmgr-glibc "$base/probe-node/glibc"
mv "$base/probe-node/bin/node" "$base/probe-node/bin/node.real"
cp /usr/share/openclawmgr/glibc-node.sh "$base/probe-node/bin/node"
cp /usr/share/openclawmgr/node-loader.cjs "$base/probe-node/node-loader.cjs"
chmod 755 "$base/probe-node/bin/node"
tar -xzf "$root/assets/sqlite-vec-0.1.7.tgz" -C "$base/probe_modules/node_modules/sqlite-vec" --strip-components=1 --no-same-owner
tar -xzf "$root/assets/sqlite-vec-linux-arm64-0.1.7.tgz" -C "$base/probe_modules/node_modules/sqlite-vec-linux-arm64" --strip-components=1 --no-same-owner
printf '%s\n' '{"name":"openclawmgr-vector-probe","private":true}' > "$base/probe_modules/package.json"
"$base/probe-node/bin/node" -e 'const {createRequire}=require("node:module");const load=createRequire(process.argv[1]+"/package.json"); const {DatabaseSync}=require("node:sqlite");const db=new DatabaseSync(":memory:",{allowExtension:true});load("sqlite-vec").load(db);db.exec("CREATE VIRTUAL TABLE v USING vec0(embedding float[2])");db.prepare("INSERT INTO v(rowid,embedding) VALUES (?,?)").run(1n,"[1,0]");const hit=db.prepare("SELECT rowid,distance FROM v WHERE embedding MATCH ? AND k=1").get("[0.9,0.1]");if(hit.rowid!==1)throw Error("nearest neighbor failed");console.log(JSON.stringify({arch:process.arch,glibc:process.report.getReport().header.glibcVersionRuntime,vec:db.prepare("SELECT vec_version() v").get().v,nearestNeighbor:hit}));' "$base/probe_modules"
