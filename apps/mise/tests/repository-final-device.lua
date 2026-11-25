-- Final deployed source smoke. Existing private fixture, original UCI unchanged.
package.path='/usr/share/agentflow/?.lua;/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local R=require('agentflow-runtime');local fs,n=s.fs,s.nixio
local app,work=arg[1],arg[2]
assert(app:match('^/mnt/mise%-runtime/acceptance/runtime%-switch%-[%w-]+/OpenClawMgr$'))
assert(not fs.lstat(work));s.mkdir(work,448)
local original=s.read('/etc/config/mise');local root=R.uci('mise.main.storage_root')
local agent='/mnt/mise-runtime/acceptance/agentflow-runtime-20261125/AgentFlow'
local bridge='/usr/share/openclawmgr/shared-runtime.lua';local checks={};local owner
local function run(argv,env,timeout)
 local rc=s.run(argv,{output=work..'/command.log',env=env,timeout=timeout or 90})
 assert(rc==0,(s.read(work..'/command.log')or''):sub(-2000));return s.read(work..'/command.log')or''
end
local function check(name,fn)fn();checks[#checks+1]={name=name,passed=true};print('PASS '..name);io.stdout:flush()end
local ok,err=pcall(function()
 check('private UCI remains unreadable to service UID; public root metadata is usable',function()
  assert(fs.stat('/etc/config/mise').modedec==600)
  require('active-root').publish(root)
  assert(fs.stat('/var/run/mise-runtime-root.json').uid==0 and fs.stat('/var/run/mise-runtime-root.json').modedec==644)
 end)
 check('same failed start generation does not submit another dependency task',function()
  local dir=app..'/log/runtime-prepare';local prior=s.read(dir..'/status.json')
  local count=#require('store').list(root..'/tasks')
  s.write(dir..'/status.json',{status='failed',storage_root=root,generation='final-failed-attempt',error='intentional retry guard fixture'})
  local rc=s.run({'/usr/bin/lua',bridge,'service',app,'--version'},{output=work..'/guard.log',timeout=20,env={OPENCLAWMGR_START_GENERATION='final-failed-attempt'}})
  if prior then s.write(dir..'/status.json',prior)end
  assert(rc~=0 and #require('store').list(root..'/tasks')==count)
 end)
 check('final atomic bindings prepare all five AgentFlow commands',function()
  run({R.helper,'ensure',agent})
  for _,a in ipairs(R.agents)do assert(run({agent..'/.runtime/bin/'..a.command,'--version'}):find(a.version,1,true))end
 end)
 check('fresh npm metadata uses the local iStoreEnhance gateway through ks-cli',function()
  local b=R.binding(agent)
  local version=run({root..'/wrap/'..b.instance,'npm','view','is-number@7.0.0','version','--cache',work..'/npm-cache'},
    {ISTORE_RUNTIME_ACCELERATION='ks-cli'},120)
  assert(version:find('7.0.0',1,true))
  local found=false
  for _,name in ipairs(require('store').list(work..'/npm-cache/_logs'))do
    if(s.read(work..'/npm-cache/_logs/'..name)or''):find('dl-npm.linkease.net:5443',1,true)then found=true end
  end
  assert(found,'Actual npm log must identify the local accelerated registry')
 end)
 check('final service entry starts Gateway as dedicated UID and sqlite-vec works',function()
  local config=s.decode(app..'/data/.openclaw/openclaw.json');local token=config.gateway.auth.token
  local rd,wr=n.pipe();local pid=assert(n.fork())
  if pid==0 then
   wr:close();assert(n.setsid());assert(rd:read(1)=='G');rd:close()
   local log=assert(n.open(work..'/gateway.log','w','600'));n.dup(log,n.stdout);n.dup(log,n.stderr);log:close()
   for _,k in ipairs({'OPENCLAW_SKIP_CHANNELS','OPENCLAW_SKIP_PROVIDERS','OPENCLAW_SKIP_CRON','OPENCLAW_SKIP_BROWSER_CONTROL_SERVER'})do n.setenv(k,'1')end
   n.setenv('OPENCLAWMGR_START_GENERATION','final-successful-attempt')
   n.exec('/usr/bin/lua',bridge,'service',app,'gateway','run','--port',tostring(config.gateway.port),'--bind','loopback','--auth','token','--token',token,'--allow-unconfigured');os.exit(127)
  end
  rd:close();for _=1,20 do owner=s.process(pid);if owner and owner.session==pid then break end;n.nanosleep(0,50000000)end
  assert(owner and owner.session==pid);wr:write('G');wr:close()
  local healthy=false
  for _=1,15 do
   local rc=s.run({'/usr/bin/lua',bridge,'as-app',app,'cli','gateway','health','--url','ws://127.0.0.1:'..config.gateway.port,'--token',token},{output=work..'/health.log',timeout=30})
   if rc==0 then healthy=true;break end;n.nanosleep(1)
  end
  assert(healthy,'Inspect private Gateway log')
  local user=n.getpw('openclawmgr');local proc=s.read('/proc/'..pid..'/status')or''
  assert(tonumber(proc:match('\nUid:%s+(%d+)'))==user.uid)
  assert(not(' '..(proc:match('\nGroups:([^\n]*)')or'')..' '):match('%s0%s'))
  local native=s.json.parse(run({'/usr/bin/lua',bridge,'as-app',app,'native'}))
  assert(native.uid==user.uid and native.sqliteVec.available and native.sqliteVec.nearestNeighbor)
  local startup=s.decode(app..'/data/.openclaw/runtime-native.json');assert(startup and startup.sqliteVec.nearestNeighbor)
  assert(s.decode(app..'/current/runtime.json').storage_root==root)
  s.stop_session(owner);n.waitpid(pid);owner=nil
 end)
end)
if owner then pcall(s.stop_session,owner)end
local unchanged=s.read('/etc/config/mise')==original
local result={passed=ok and unchanged,checks=checks,system_configuration_unchanged=unchanged,
 error=not ok and(type(err)=='table'and err.message or tostring(err))or nil}
s.write(work..'/result.json',result);print(s.json.stringify(result));os.exit(result.passed and 0 or 1)
