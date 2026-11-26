-- Destructive probes are restricted to this milestone's dedicated test app.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local base,work=assert(arg[1]),assert(arg[2])
assert(base:find('/M5/OpenClawMgr',1,true)and fs.realpath(base)==base)
s.mkdir(work,448)
local manager='/usr/libexec/istorec/openclawmgr.sh'
local binding=s.decode(base..'/current/runtime.json')
local checks={}
local function check(name,ok)
  checks[#checks+1]={name=name,passed=not not ok};s.write(work..'/result.json',{checks=checks})
  assert(ok,name)
end
local function call(args,timeout)
  return s.run(args,{output=work..'/private-output',timeout=timeout or 100}),s.read(work..'/private-output')
end
local function running()
  local rc,raw=s.pipe_capture({'/bin/ubus','call','service','list','{"name":"openclawmgr"}'})
  local r=rc==0 and s.json.parse(raw)
  local i=r and r.openclawmgr and r.openclawmgr.instances and r.openclawmgr.instances.gateway
  return i and i.running
end
local rc,path=call({base..'/node/bin/node','-e',"const {createRequire}=require('node:module');process.stdout.write(createRequire(process.argv[1])('sqlite-vec').getLoadablePath())",base..'/global/lib/node_modules/openclaw/package.json'})
assert(rc==0);path=path:gsub('%s+$','');assert(path:sub(1,#base+1)==base..'/')
local receipt=binding.storage_root..'/environments/'..binding.instance..'/receipt.json'
local hidden
local ok,err=pcall(function()
  check('stop before dependency fault',call({manager,'stop'})==0)
  assert(fs.rename(path,path..'.M5-disabled'));hidden=path
  check('missing vector extension refuses public start',call({manager,'start'})~=0)
  check('missing vector extension has no running Gateway',not running())
  assert(fs.rename(hidden..'.M5-disabled',hidden));hidden=nil
  check('restored extension passes public restart and health',call({manager,'restart'})==0)
  check('stop before SDK fault',call({manager,'stop'})==0)
  assert(fs.rename(receipt,receipt..'.M5-disabled'));hidden=receipt
  local status,output=call({manager,'status'})
  check('missing exact SDK reports runtime-missing',status==0 and output:match('runtime%-missing'))
  check('missing exact SDK refuses start instead of fallback',call({manager,'start'})~=0 and not running())
  assert(fs.rename(hidden..'.M5-disabled',hidden));hidden=nil
  check('restored exact SDK restarts with health',call({manager,'restart'})==0)
end)
if hidden then assert(fs.rename(hidden..'.M5-disabled',hidden));call({manager,'restart'})end
if not ok then error(err)end
local after=s.decode(base..'/current/runtime.json')
check('dependency failures preserve exact application binding',s.json.stringify(binding)==s.json.stringify(after))
local report={passed=true,boot_id=s.boot_id(),arch=s.nixio.uname().machine,checks=checks,instance=binding.instance}
s.write(work..'/result.json',report);fs.unlink(work..'/private-output')
print(s.json.stringify(report))
