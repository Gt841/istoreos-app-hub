-- Actual deployed application probe. Never emit authentication material.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local base,evidence=assert(arg[1]),assert(arg[2])
local bridge='/usr/share/openclawmgr/shared-runtime.lua'
s.mkdir(evidence,448)
local result={schema_version=1,boot_id=s.boot_id(),arch=s.nixio.uname().machine,base=base,checks={}}
local function check(name,value)
  result.checks[#result.checks+1]={name=name,passed=not not value}
  s.write(evidence..'/gateway-result.json',result)
  assert(value,name)
end
local function run(name,argv,timeout)
  local output=evidence..'/probe-output'
  local rc=s.run(argv,{output=output,timeout=timeout or 30})
  check(name,rc==0)
  return s.read(output)
end
local b=s.json.parse(run('fixed binding validates',{'/usr/bin/lua',bridge,'inspect',base..'/current/runtime.json'}))
result.runtime=b
local r=s.decode(base..'/current/receipt.json')
check('application receipt uses fixed public SDK',r and r.runtime.kind=='mise-runtime'and r.runtime.instance==b.instance and r.runtime.storageRoot==b.storage_root)
check('application Node is a small wrapper',fs.stat(base..'/node/bin/node').size<4096 and not fs.lstat(base..'/node/glibc'))
local rc,raw=s.pipe_capture({'/bin/ubus','call','service','list','{"name":"openclawmgr"}'})
local service=rc==0 and s.json.parse(raw)
local instance=service and service.openclawmgr and service.openclawmgr.instances and service.openclawmgr.instances.gateway
check('procd Gateway is running',instance and instance.running and instance.pid)
local proc=s.read('/proc/'..instance.pid..'/status')or''
local account=s.nixio.getpw('openclawmgr')
result.process={pid=instance.pid,uid=tonumber(proc:match('\nUid:%s+(%d+)')),gid=tonumber(proc:match('\nGid:%s+(%d+)'))}
check('Gateway runs as dedicated nonroot user',account and account.uid>0 and result.process.uid==account.uid and result.process.gid==account.gid)
check('Gateway has no root supplementary group',not (' '..(proc:match('\nGroups:([^\n]*)')or'')..' '):match('%s0%s'))
local config=s.decode(base..'/data/.openclaw/openclaw.json')
check('test Gateway is loopback only',config.gateway.bind=='loopback')
run('authenticated Gateway health',{'/usr/bin/lua',bridge,'as-app',base,'cli','gateway','health','--url','ws://127.0.0.1:'..config.gateway.port,'--token',config.gateway.auth.token},90)
local native=s.json.parse(run('native checks execute as service user',{'/usr/bin/lua',bridge,'as-app',base,'native'},60))
check('service UID sqlite-vec nearest neighbor through OpenClaw loader',native and native.uid==account.uid and native.sqliteVec and native.sqliteVec.available and native.sqliteVec.nearestNeighbor and native.sqliteVec.loader=='openclaw-memory-host')
result.native=native
local startup=s.decode(base..'/data/.openclaw/runtime-native.json')
check('Gateway startup required OpenClaw loader vector query',startup and startup.uid==account.uid and startup.sqliteVec and startup.sqliteVec.nearestNeighbor and startup.sqliteVec.loader=='openclaw-memory-host')
result.startup_native=startup
check('Gateway username and HOME match application identity',startup.user=='openclawmgr'and startup.home==base..'/data')
result.passed=true
s.write(evidence..'/gateway-result.json',result)
fs.unlink(evidence..'/probe-output')
print(s.json.stringify(result))
