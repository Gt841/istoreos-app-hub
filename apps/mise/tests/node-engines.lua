-- Deliberately incompatible npm fixture is never part of the production catalog.
local share,root,mise,entry_path=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks');local contract=require('contract')
local ctx=store.open(root);ctx.share=share;ctx.mise_bin=mise
local e=assert(sys.decode(entry_path));ctx.catalog={entries={e}}
local lib=require('libraries').definition(e.arch).id
local id=contract.instance_id(e,nil,lib)
local before=store.state(ctx).revision
local old
for _,name in ipairs(store.list(root..'/environments'))do
  local r=sys.decode(root..'/environments/'..name..'/receipt.json')
  if r and r.verified and r.entry.tool=='node'then old=name;break end
end
assert(old,'no existing instance to preserve')
local binary=root..'/environments/'..old..'/bin/node.real'
local previous=sys.sha(binary,root..'/work')
local t=tasks.start(ctx,{entry=e.id,instance=id,source='origin'},function(c,task,w,log)return require('adapters').install(c,task,w,log)end)
local finished
for _=1,240 do
  local current=tasks.get(ctx,t.id)
  if current.status~='running'then finished=current;break end
  sys.nixio.nanosleep(0,500000000)
end
assert(finished and finished.status=='failed',sys.json.stringify(finished))
assert(finished.error.code=='PROBE_FAILED'and finished.error.message:find('npm engines',1,true),sys.json.stringify(finished.error))
assert(not sys.fs.lstat(root..'/environments/'..id)and not sys.fs.lstat(root..'/wrap/'..id))
assert(not sys.fs.lstat(root..'/.lock')and store.state(ctx).revision==before)
assert(sys.sha(binary,root..'/work')==previous)
print('PASS incompatible actual npm engines rejects candidate and preserves existing Node, state and lock')
