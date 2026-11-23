set -eu
test_root='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123'
base='/mnt/vio4-0/OpenClawMgr-acceptance-20261123'
PATH="$test_root/tools-node/bin:/usr/sbin:/usr/bin:/sbin:/bin" npm_config_cache="$base/npm-cache" timeout -k 2 30 ks-cli npm pack sqlite-vec-linux-x64@0.1.7 --ignore-scripts --json --pack-destination "$test_root/native-probe" > "$test_root/native-probe/pack.json"
tar -xzf "$test_root/native-probe/sqlite-vec-linux-x64-0.1.7.tgz" -C "$test_root/native-probe" --no-same-owner
VEC_PATH="$test_root/native-probe/package/vec0.so" "$test_root/tools-node/bin/node" - <<'NODE'
const fs=require('node:fs');
const path=process.env.VEC_PATH;
console.log('vec_file_exists='+fs.existsSync(path));
try { process.dlopen({exports:{}},path); console.log('dlopen=success'); }
catch (error) { console.log('dlopen_error='+error.message); }
NODE
