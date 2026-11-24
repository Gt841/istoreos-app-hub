local root,output=arg[1],arg[2]
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local c=require('contract');c.path(root)
local ctx=store.open(root);local receipt
for _,id in ipairs(store.list(root..'/environments'))do local r=sys.decode(root..'/environments/'..id..'/receipt.json');if r and r.verified and r.entry.abi=='glibc'then receipt=r;break end end
assert(receipt);local home=root..'/users/65001/home';local work=root..'/work/installed-user-check';sys.mkdir(work,448)
sys.write(work..'/request',{op='prepare-user',uid=65001,gid=65001})
assert(sys.run({'/usr/sbin/mise-runtime','request'},{stdin=work..'/request',output=work..'/prepare',timeout=30})==0)
local expected=assert(sys.decode(work..'/prepare'));assert(expected.ok and expected.value.home==home)
local js=[[const a=require('node:assert/strict');a.equal(process.getuid(),65001);a.equal(process.env.HOME,process.argv[1]);a.equal(process.env.ISTORE_RUNTIME_HOME,process.argv[1]);a.ok(process.env.TMPDIR.startsWith(process.argv[1]+'/'));const v=require('node:child_process').execFileSync(process.execPath,['--version'],{encoding:'utf8'}).trim();a.equal(v,'v24.21.0');console.log(JSON.stringify({uid:process.getuid(),home:process.env.HOME,tmp:process.env.TMPDIR,node:v,execPath:process.execPath}));]]
assert(sys.run({root..'/wrap/'..receipt.instance,'node','-e',js,home},{uid=65001,gid=65001,env={ISTORE_RUNTIME_ACCELERATION='origin'},output=output,timeout=30})==0,sys.read(output))
assert(sys.run({root..'/wrap/'..receipt.instance,'npm','--version'},{uid=65001,gid=65001,env={ISTORE_RUNTIME_ACCELERATION='origin'},output=work..'/npm',timeout=30})==0,sys.read(work..'/npm'))
assert(sys.read(work..'/npm')==receipt.npm..'\n')
print(assert(sys.read(output)))
print('PASS installed package ordinary UID HOME/TMP, fixed execPath/child and npm')
sys.remove(work)
