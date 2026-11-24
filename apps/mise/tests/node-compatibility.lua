local share,root,mise,base=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local registration=require('registration')
local ctx=store.open(root);ctx.share=share;ctx.mise_bin=mise
local work=root..'/work/node-compatibility';sys.mkdir(work,448)
local receipts={};local remove
for _,id in ipairs(store.list(root..'/environments'))do
  local r=sys.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and r.entry.tool=='node'then receipts[#receipts+1]=r;if r.npm=='11.12.1'and r.entry.abi=='glibc'then remove=r end end
end
assert(#receipts==5 and remove)
for _,r in ipairs(receipts)do
  registration.register(ctx,r,work,work..'/mise.log')
  local scope=registration.scope(ctx,r.entry)
  local env={HOME=scope.home,MISE_DATA_DIR=scope.data,MISE_CONFIG_DIR=scope.config,MISE_CACHE_DIR=scope.cache,MISE_STATE_DIR=scope.state,ISTORE_RUNTIME_ACCELERATION='origin'}
  assert(sys.run({mise,'exec','node@'..r.mise_key,'--','node','--version'},{env=env,cwd=work,output=work..'/version',timeout=30})==0)
  assert(sys.read(work..'/version')=='v'..r.entry.version..'\n')
end
print('PASS five actual SDK registrations and mise exec use the same installations')
local r=receipts[1];local out=root..'/users/65001/mise-output'
local argv={root..'/wrap/'..r.instance,'--shell','-c','exec "$1" exec "$2" -- node --version','probe',mise,'node@'..r.mise_key}
assert(sys.run(argv,{uid=65001,gid=65001,output=out,env={ISTORE_RUNTIME_ACCELERATION='origin'},timeout=30})==0,sys.read(out))
assert(sys.read(out)=='v'..r.entry.version..'\n')
print('PASS ordinary UID can read the managed mise registry and execute an exact key')
local function cli(request,code)
  sys.write(work..'/request',request)
  local rc=sys.run({'/usr/bin/lua',share..'/main.lua','request'},{stdin=work..'/request',output=work..'/response',env={MISE_RUNTIME_ROOT=root,MISE_RUNTIME_MISE_BIN=mise},timeout=30})
  local v=sys.decode(work..'/response')
  if code then assert(rc~=0 and not v.ok and v.error.code==code,sys.json.stringify(v))else assert(rc==0 and v.ok,sys.json.stringify(v))end
end
local scope=registration.scope(ctx,remove.entry);local config=scope.config..'/config.toml';local before=sys.read(config)
sys.write(config,'[tools]\nnode="'..remove.mise_key..'"\n')
local ok,err=pcall(function()cli({op='remove',id=remove.instance},'BUSY')end)
if before then sys.write(config,before)else sys.fs.unlink(config)end
if not ok then error(err)end
assert(sys.fs.stat(root..'/environments/'..remove.instance))
print('PASS actual installed SDK selected as a default is protected; isolated config restored')
local links={}
for name in sys.fs.dir(scope.data..'/installs/node')do
  local path=scope.data..'/installs/node/'..name
  if sys.fs.lstat(path).type=='lnk'and sys.fs.realpath(path)==root..'/environments/'..remove.instance then links[#links+1]=path end
end
assert(#links>0)
cli({op='remove',id=remove.instance})
for _,path in ipairs(links)do assert(not sys.fs.lstat(path),'owned mise alias remains: '..path)end
assert(not sys.fs.lstat(root..'/environments/'..remove.instance)and not sys.fs.lstat(root..'/wrap/'..remove.instance))
assert(sys.fs.stat(root..'/environments/'..r.instance)or r.instance==remove.instance)
print('PASS explicit nondefault uninstall removes SDK, wrap and all owned aliases')
print('NOTE caller must reinstall the removed npm variant with node-install.lua all')
