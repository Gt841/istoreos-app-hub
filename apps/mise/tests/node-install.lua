local share,root,mise,ks,admin,selection=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks')
local contract=require('contract');local ctx=store.open(root)
local work=root..'/work/node-install-test';sys.mkdir(work,448)
local env={MISE_RUNTIME_ROOT=root,MISE_RUNTIME_MISE_BIN=mise,MISE_RUNTIME_KS_CLI=ks,MISE_RUNTIME_ADMIN_URL=admin,MISE_RUNTIME_DOWNLOAD_MODE=selection=='all-accelerated'and'accelerated'or nil}
local function cli(request)
  sys.write(work..'/request.json',request)
  local rc=sys.run({'/usr/bin/lua',share..'/main.lua','request'},{env=env,stdin=work..'/request.json',output=work..'/response.json',timeout=45})
  local r=sys.decode(work..'/response.json');assert(rc==0 and r and r.ok,sys.json.stringify(r))
  return r.value
end
local arch=sys.nixio.uname().machine
local selected={}
for _,e in ipairs(sys.decode(share..'/catalog.json').entries)do
  if e.tool=='node'and e.arch==arch then
    local wanted=selection=='one'and e.version=='24.21.0'and e.abi=='glibc'and #e.artifacts==1
      or(selection=='all'or selection=='all-accelerated')and(#e.artifacts==1 or(e.version=='24.21.0'and e.abi=='glibc'))
    if wanted then selected[#selected+1]=e end
  end
end
assert(#selected>0)
for _,entry in ipairs(selected)do
  local lib=entry.abi=='glibc'and require('libraries').definition(arch).id or nil
  local id=contract.instance_id(entry,nil,lib)
  if sys.fs.access(root..'/wrap/'..id,'x')then
    local r=cli({op='inspect',id=id});assert(r.verified);print('REUSE '..entry.id)
  else
    local plan=cli({op='plan',entry=entry.id,source='ks-cli'})
    local task=cli({op='submit',id=plan.id});print('START '..entry.id..' '..task.id);io.stdout:flush()
    local finished
    for _=1,1800 do
      local current=tasks.get(ctx,task.id)
      if current.status~='running'then finished=current;break end
      sys.nixio.nanosleep(0,500000000)
    end
    assert(finished,'installation exceeded 900s')
    if finished.status~='success'then
      io.stderr:write(sys.json.stringify(finished)..'\n'..(sys.read(root..'/tasks/'..task.id..'/log')or''));os.exit(1)
    end
    local r=cli({op='inspect',id=id});assert(r.verified and r.npm==entry.npm)
    assert(sys.fs.access(root..'/wrap/'..id,'x'));print('PASS '..entry.id);io.stdout:flush()
  end
end
print('installed='..#selected)
