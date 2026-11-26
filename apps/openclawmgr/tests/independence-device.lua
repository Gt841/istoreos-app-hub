package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local base,work,source=assert(arg[1]),assert(arg[2]),assert(arg[3])
assert(base:find('/M5/OpenClawMgr',1,true));assert(source=='origin'or source=='ks-cli');s.mkdir(work,448)
local ref=s.decode(base..'/current/runtime.json')
local binding_hash=s.sha(base..'/current/runtime.json',work)
local config_hash=s.sha('/etc/config/mise',work)
local function pid()
  local rc,raw=s.pipe_capture({'/bin/ubus','call','service','list','{"name":"openclawmgr"}'})
  local service=rc==0 and s.json.parse(raw)
  local instance=service and service.openclawmgr and service.openclawmgr.instances and service.openclawmgr.instances.gateway
  assert(instance and instance.running);return instance.pid
end
local before=pid()
local function request(value)
  s.write(work..'/request.json',value)
  local rc=s.run({'/usr/sbin/mise-runtime','request'},{stdin=work..'/request.json',output=work..'/response.json',env={MISE_RUNTIME_ROOT=ref.storage_root},timeout=90})
  local response=s.decode(work..'/response.json')
  assert(rc==0 and response.ok,response and response.error and response.error.message or'public request failed')
  return response.value
end
local entry
for _,e in ipairs(request({op='catalog'}).entries)do
  if e.tool=='node'and e.version=='24.21.0'and e.npm=='11.12.1'and e.arch==s.nixio.uname().machine and e.abi=='glibc'then entry=e;break end
end
assert(entry)
local id=require('contract').instance_id(entry,nil,ref.library)
if not fs.lstat(ref.storage_root..'/environments/'..id)then
  local plan=request({op='plan',entry=entry.id,source=source})
  local task=request({op='submit',id=plan.id})
  local began=os.time()
  while true do
    local t=s.decode(ref.storage_root..'/tasks/'..task.id..'/task.json')
    if t.status=='success'then break end
    assert(t.status=='running',t.error and t.error.message or t.status)
    assert(os.time()-began<700,'additional SDK install timed out');s.nixio.nanosleep(1)
  end
end
-- Test a real future library revision in the same storage. The maintained
-- recipe is identical to normal provisioning; no installed payload is copied.
local store=require('store');local ctx=store.open(ref.storage_root);ctx.share='/usr/share/mise-runtime'
local lock='m5-library-independence-'..s.nixio.getpid();store.lock(ctx,{id=lock,boot=s.boot_id()})
local ok,lib=pcall(function()
  local result=require('libraries').ensure(ctx,require('libraries').definition(s.nixio.uname().machine,'r2'),source,work,work..'/library-private.log')
  store.bump(ctx);return result
end)
store.unlock(ctx,lock);assert(ok,type(lib)=='table'and lib.message or tostring(lib))
local function version(command)
  local rc=s.run({ref.storage_root..'/wrap/'..id,command,'--version'},{output=work..'/version',env={ISTORE_RUNTIME_ACCELERATION='origin'},timeout=30})
  assert(rc==0);return(s.read(work..'/version')or''):gsub('%s+$','')
end
local checks={
  {name='additional Node version executes',passed=version('node')=='v24.21.0'},
  {name='independent npm version executes',passed=version('npm')=='11.12.1'},
  {name='additional library revision verified',passed=lib.verified and lib.id~=ref.library},
  {name='Gateway fixed binding unchanged',passed=s.sha(base..'/current/runtime.json',work)==binding_hash},
  {name='global mise configuration unchanged',passed=s.sha('/etc/config/mise',work)==config_hash},
  {name='existing Gateway process continues',passed=pid()==before}
}
local rc=s.run({'/usr/bin/lua','/usr/share/openclawmgr/shared-runtime.lua','as-app',base,'native'},{output=work..'/native-private',timeout=90})
local native=rc==0 and s.json.parse(s.read(work..'/native-private'))
checks[#checks+1]={name='fixed application OpenClaw vector query remains available',passed=native and native.sqliteVec and native.sqliteVec.nearestNeighbor}
local passed=true;for _,c in ipairs(checks)do passed=passed and c.passed end
local report={passed=passed,arch=s.nixio.uname().machine,boot_id=s.boot_id(),additional_instance=id,additional_library=lib.id,checks=checks}
s.write(work..'/result.json',report);print(s.json.stringify(report));assert(passed)
