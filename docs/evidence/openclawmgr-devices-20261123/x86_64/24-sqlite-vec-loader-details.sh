set -eu
test_root='/mnt/vio4-0/Configs/openclawmgr-acceptance-20261123'
VEC_PATH="$test_root/native-probe/package/vec0.so" "$test_root/tools-node/bin/node" - <<'NODE'
const {constants}=require('node:os');
const {DatabaseSync}=require('node:sqlite');
const path=process.env.VEC_PATH;
try {process.dlopen({exports:{}},path,constants.dlopen.RTLD_NOW)} catch(e){console.log('dlopen_now='+e.message)}
for (const explicit of [false,true]) {
 const db=new DatabaseSync(':memory:',{allowExtension:true});
 try {explicit ? db.loadExtension(path,'sqlite3_vec_init') : db.loadExtension(path); console.log('extension='+JSON.stringify(db.prepare('select vec_version() v').get()))}
 catch(e){console.log('explicit='+explicit+' extension_error='+e.message)}
 finally{db.close()}
}
NODE
