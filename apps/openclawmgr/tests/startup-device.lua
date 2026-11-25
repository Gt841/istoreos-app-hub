-- Formal procd startup, fixed runtime, non-root identity and vector acceptance.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local u=require('luci.model.uci').cursor()
local base=assert(u:get('openclawmgr','main','base_dir'));local work=arg[1]
assert(not s.fs.lstat(work));s.mkdir(work,448)
local service=require('luci.util').ubus('service','list',{name='openclawmgr'})
local instance=service and service.openclawmgr and service.openclawmgr.instances and service.openclawmgr.instances.gateway
local checks={procd_running=instance and instance.running==true or false}
local pid=instance and instance.pid
local uid,home,runtime_home
if pid then
 local status=s.read('/proc/'..pid..'/status')or'';uid=tonumber(status:match('Uid:%s+(%d+)'))
 for v in(s.read('/proc/'..pid..'/environ')or''):gmatch('[^%z]+')do
  local k,value=v:match('^([^=]+)=(.*)$')
  if k=='HOME'then home=value elseif k=='ISTORE_RUNTIME_HOME'then runtime_home=value end
 end
end
local user=s.nixio.getpw('openclawmgr')
checks.dedicated_uid=uid~=nil and user~=nil and uid==user.uid and uid>0
checks.application_home=home==base..'/data'and runtime_home==home
local binding=s.decode(base..'/current/runtime.json')
checks.current_repository=binding~=nil and binding.storage_root==u:get('mise','main','storage_root')
local preparation=s.decode(base..'/log/runtime-prepare/status.json')
checks.preparation_ready=preparation~=nil and preparation.status=='ready'
local native=s.decode(base..'/data/.openclaw/runtime-native.json')
checks.sqlite_vec=native~=nil and native.sqliteVec~=nil and native.sqliteVec.available==true and native.sqliteVec.nearestNeighbor==true
local config=s.decode(base..'/data/.openclaw/openclaw.json')or{}
local port=tostring(config.gateway and config.gateway.port or u:get('openclawmgr','main','port')or'18789')
local token=config.gateway and config.gateway.auth and config.gateway.auth.token or u:get('openclawmgr','main','token')or''
checks.authenticated_health=s.run({'/usr/bin/lua','/usr/share/openclawmgr/shared-runtime.lua','as-app',base,'cli',
 'gateway','health','--url','ws://127.0.0.1:'..port,'--token',token},{output=work..'/health.log',timeout=90})==0
local passed=true;for _,value in pairs(checks)do if not value then passed=false end end
local report={passed=passed,checks=checks,pid=pid,uid=uid,base_dir=base,storage_root=binding and binding.storage_root,
 node=binding and binding.node,npm=binding and binding.npm,sqlite_vec=native and native.sqliteVec}
s.write(work..'/result.json',report);print(s.json.stringify(report));os.exit(passed and 0 or 1)
