-- Real disk/SDK/app tests. Task-owned roots; restore system settings/bindings.
package.path='/usr/share/agentflow/?.lua;/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local tasks=require('tasks');local c=require('contract')
local R=require('agentflow-runtime');local A=require('agentflow-agents');local fs,n=s.fs,s.nixio
local work,label=arg[1],arg[2]
assert(work:match('^/mnt/mise%-runtime/acceptance/runtime%-switch%-[%w-]+$'))
assert(not fs.lstat(work),'Use a fresh test directory');s.mkdir(work,493)
local original=s.read('/etc/config/mise');local mode=tonumber(tostring(fs.stat('/etc/config/mise').modedec),8)
local live=R.uci('mise.main.storage_root');local rootA=work..'/Runtime-A'
local rootB='/mnt/vio4-0/Configs/Runtime-switch-'..c.key(label)
assert(not fs.lstat(rootB),'Refuse to replace another test repository')
local agent='/mnt/mise-runtime/acceptance/agentflow-runtime-20261125/AgentFlow'
local originalApp='/mnt/mise-runtime/acceptance/M5/OpenClawMgr'
local app=work..'/OpenClawMgr';local bridge='/usr/share/openclawmgr/shared-runtime.lua'
local bindingBackups={};local checks={};local gateway
local e,id,library=R.policy(live)
local originalSDK=s.sha(live..'/environments/'..id..'/receipt.json',work)
local originalLibrary=s.sha(live..'/libraries/'..library..'/SHA256SUMS',work)
local function check(name,fn)
 fn();checks[#checks+1]={name=name,passed=true};s.write(work..'/checks.json',{checks=checks});print('PASS '..name);io.stdout:flush()
end
local function cli(value,root,code)
 local input=work..'/request.json';s.write(input,value)
 local env={};if root~=nil then env.MISE_RUNTIME_ROOT=root end
 local rc=s.run({'/usr/sbin/mise-runtime','request'},{stdin=input,output=work..'/response.json',env=env,timeout=60})
 local response=s.decode(work..'/response.json');assert(response,s.read(work..'/response.json'))
 if code then assert(rc~=0 and response.error and response.error.code==code,s.json.stringify(response))
 else assert(rc==0 and response.ok,s.json.stringify(response))end
 return response.value
end
local function wait(ctx,t)
 for _=1,900 do
  t=tasks.get(ctx,t.id);assert(t)
  if t.status~='running'then assert(t.status=='success',s.json.stringify(t.error));return t end
  n.nanosleep(1)
 end
 error('Task exceeded 900s')
end
local function run(argv,timeout)
 local rc=s.run(argv,{output=work..'/command.log',timeout=timeout or 60})
 assert(rc==0,(s.read(work..'/command.log')or''):sub(-2000));return s.read(work..'/command.log')or''
end
local function cache(root)
 local pins={require('libraries').definition(e.arch).libc,require('libraries').definition(e.arch).gcc}
 for _,pin in ipairs(e.artifacts)do pins[#pins+1]=pin end
 for _,pin in ipairs(pins)do
  local source=live..'/cache/'..pin.sha256
  assert(s.sha(source,work)==pin.sha256,'Missing verified source archive')
  run({'cp',source,root..'/cache/'..pin.sha256})
 end
end
local ok,err=pcall(function()
 check('initialize an empty repository without touching system configuration',function()
  local state=cli({op='settings',path=rootA,acceleration=true},'')
  assert(state.path==rootA and #state.runtimes==0 and not state.storage_locked)
  assert(s.read('/etc/config/mise')==original)
 end)
 local ctxA=store.open(rootA);ctxA.share='/usr/share/mise-runtime';ctxA.catalog=s.decode(ctxA.share..'/catalog.json');ctxA.mise_bin='/usr/bin/mise'
 cache(rootA)
 check('concurrent exact SDK requests share the same real install task',function()
  local first=cli({op='ensure',entry=e.id,library=library,source='ks-cli'},rootA)
  local second=cli({op='ensure',entry=e.id,library=library,source='ks-cli'},rootA)
  assert(first.owned and not second.owned and first.task.id==second.task.id)
  wait(ctxA,first.task)
  assert(s.decode(rootA..'/environments/'..id..'/receipt.json').verified)
 end)
 check('switch away from populated live storage while preserving old SDK/library',function()
  local state=cli({op='settings',path=rootA,acceleration=true})
  assert(state.path==rootA and #state.runtimes==1 and not state.storage_locked)
  assert(R.uci('mise.main.storage_root')==rootA)
  assert(s.sha(live..'/environments/'..id..'/receipt.json',work)==originalSDK)
  assert(s.sha(live..'/libraries/'..library..'/SHA256SUMS',work)==originalLibrary)
 end)
 check('an active task blocks switching and invalid storage preserves selection',function()
  local task=tasks.start(ctxA,{id='hold-switch',kind='test'},function()n.nanosleep(60);return{}end)
  cli({op='settings',path=rootB,acceleration=true},nil,'BUSY')
  assert(not fs.lstat(rootB)and R.uci('mise.main.storage_root')==rootA)
  tasks.recover(ctxA,task.id,true)
  cli({op='settings',path='/mnt/runtime-switch-unmounted/Runtime',acceleration=true},nil,'OFFLINE')
  assert(R.uci('mise.main.storage_root')==rootA)
 end)
 check('switch to another disk starts empty and uses its persistent HOME',function()
  local state=cli({op='settings',path=rootB,acceleration=true})
  assert(state.path==rootB and #state.runtimes==0 and #state.libraries==0)
  assert(state.managed_home==rootB..'/home')
  assert(s.decode(rootA..'/environments/'..id..'/receipt.json').verified)
 end)
 cache(rootB)
 -- Clone installed application code only; all Gateway data/config are private.
 s.mkdir(app..'/releases/probe',493)
 run({'cp','-a',originalApp..'/current/.',app..'/releases/probe'})
 assert(fs.symlink('releases/probe',app..'/current'))
 assert(fs.symlink('current/node',app..'/node')and fs.symlink('current/global',app..'/global'))
 s.mkdir(app..'/data/.openclaw',448)
 local token=s.identifier('private-test-token')
 s.write(app..'/data/.openclaw/openclaw.json',{gateway={mode='local',port=18894,bind='loopback',auth={mode='token',token=token}}})
 local user=n.getpw('openclawmgr');assert(user and user.uid>0)
 run({'chown','-R',tostring(user.uid)..':'..user.gid,app..'/data'})
 for _,a in ipairs(R.agents)do
  local dir=fs.realpath(agent..'/.runtime/agents/'..a.id..'/current');assert(dir)
  bindingBackups[dir..'/runtime.json']=s.read(dir..'/runtime.json')
 end
 bindingBackups[agent..'/.runtime/runtime.json']=s.read(agent..'/.runtime/runtime.json')
 check('old bindings cannot silently execute against the previous repository',function()
  assert(not pcall(R.binding,agent))
  assert(s.run({'/usr/bin/lua',bridge,'inspect',app..'/current/runtime.json'},{output=work..'/stale.log',timeout=15})~=0)
 end)
 check('OpenClaw automatically installs its original fixed SDK in the empty selected repository',function()
  run({'/usr/bin/lua',bridge,'prepare',app..'/current/runtime.json'},900)
  local b=s.decode(app..'/current/runtime.json')
  assert(b.storage_root==rootB and b.instance==id and b.library==library)
 end)
 check('AgentFlow rebinds the top-level SDK and all five active agent releases',function()
  run({R.helper,'ensure',agent},900)
  for path in pairs(bindingBackups)do assert(s.decode(path).storage_root==rootB)end
  for _,a in ipairs(R.agents)do assert(run({agent..'/.runtime/bin/'..a.command,'--version'}):find(a.version,1,true))end
  assert(run({agent..'/.runtime/bin/node','-p','process.env.HOME'}):gsub('%s+$','')==rootB..'/home')
 end)
 local ctxB=store.open(rootB);ctxB.share=ctxA.share;ctxB.catalog=ctxA.catalog;ctxB.mise_bin='/usr/bin/mise'
 check('glibc with environment references cannot be removed',function()
  cli({op='library-remove',id=library},rootB,'BUSY')
 end)
 local lib=rootB..'/libraries/'..library
 local expected=s.decode(lib..'/receipt.json').manifest_sha256
 check('missing glibc is restored without deleting an existing SDK',function()
  assert(fs.rename(lib,rootB..'/work/missing-library-preserved'))
  local state=cli({op='read'},rootB);assert(#state.libraries==1 and state.libraries[1].missing)
  local t=cli({op='library-repair',id=library,source='ks-cli'},rootB)
  wait(ctxB,t.task)
  assert(s.decode(lib..'/receipt.json').manifest_sha256==expected)
  assert(run({rootB..'/wrap/'..id,'node','--version'}):find(e.version,1,true))
 end)
 check('failed and canceled library repairs restore their exact prior directory',function()
  local old=fs.stat(lib).ino
  local t=tasks.start(ctxB,{id='repair-fault',kind='test'},function(cx,task,w,log)
    require('libraries').ensure(cx,require('libraries').definition(e.arch),'ks-cli',w,log,{repair=true,task=task})
    error('intentional post-publication fault')
  end)
  for _=1,120 do local current=tasks.get(ctxB,t.id);if current.status~='running'then assert(current.status=='failed');break end;n.nanosleep(1)end
  assert(fs.stat(lib).ino==old and not fs.lstat(rootB..'/.lock'))
  t=tasks.start(ctxB,{id='repair-cancel',kind='test'},function(cx,task,w,log)
    require('libraries').ensure(cx,require('libraries').definition(e.arch),'ks-cli',w,log,{repair=true,task=task})
    n.nanosleep(60)
  end)
  for _=1,120 do local current=tasks.get(ctxB,t.id);if current.library_publication and fs.stat(lib).ino~=old then break end;n.nanosleep(1)end
  tasks.recover(ctxB,t.id,true)
  assert(fs.stat(lib).ino==old and not fs.lstat(rootB..'/.lock'))
 end)
 check('damaged glibc is repaired and original binding content identity remains valid',function()
  local f=assert(io.open(lib..'/libm.so.6','ab'));f:write('intentional-library-damage');f:close()
  local t=cli({op='library-repair',id=library,source='ks-cli'},rootB);wait(ctxB,t.task)
  assert(s.decode(lib..'/receipt.json').manifest_sha256==expected)
  assert(R.binding(agent).storage_root==rootB)
 end)
 check('Gateway startup prepares dependencies and drops to the dedicated user',function()
  local rd,wr=n.pipe();local pid=assert(n.fork())
  if pid==0 then
   wr:close();assert(n.setsid());assert(rd:read(1)=='G');rd:close()
   local log=assert(n.open(work..'/gateway.log','w','600'));n.dup(log,n.stdout);n.dup(log,n.stderr);log:close()
   n.setenv('OPENCLAW_SKIP_CHANNELS','1');n.setenv('OPENCLAW_SKIP_PROVIDERS','1');n.setenv('OPENCLAW_SKIP_CRON','1');n.setenv('OPENCLAW_SKIP_BROWSER_CONTROL_SERVER','1')
   n.exec('/usr/bin/lua',bridge,'service',app,'gateway','run','--port','18894','--bind','loopback','--auth','token','--token',token,'--allow-unconfigured');os.exit(127)
  end
  rd:close();for _=1,20 do gateway=s.process(pid);if gateway and gateway.session==pid then break end;n.nanosleep(0,50000000)end
  assert(gateway and gateway.session==pid);wr:write('G');wr:close()
  local healthy=false
  for _=1,20 do
   local rc=s.run({'/usr/bin/lua',bridge,'as-app',app,'cli','gateway','health','--url','ws://127.0.0.1:18894','--token',token},{output=work..'/health.log',timeout=30})
   if rc==0 then healthy=true;break end;n.nanosleep(1)
  end
  assert(healthy,'Gateway failed health; inspect private gateway.log')
  local status=s.read('/proc/'..pid..'/status')or''
  assert(tonumber(status:match('\nUid:%s+(%d+)'))==user.uid)
  assert(not(' '..(status:match('\nGroups:([^\n]*)')or'')..' '):match('%s0%s'))
  local native=s.json.parse(run({'/usr/bin/lua',bridge,'as-app',app,'native'}))
  assert(native.uid==user.uid and native.sqliteVec.available and native.sqliteVec.nearestNeighbor)
  local startup=s.decode(app..'/data/.openclaw/runtime-native.json')
  assert(startup and startup.sqliteVec.nearestNeighbor and startup.home==app..'/data')
  s.stop_session(gateway);n.waitpid(pid);gateway=nil
 end)
 check('switching back reuses the old repository and never changes its SDK content',function()
  local state=cli({op='settings',path=live,acceleration=true})
  assert(state.path==live and #state.runtimes>=11)
  assert(s.sha(live..'/environments/'..id..'/receipt.json',work)==originalSDK)
  assert(s.sha(live..'/libraries/'..library..'/SHA256SUMS',work)==originalLibrary)
 end)
end)
if gateway then pcall(s.stop_session,gateway)end
for path,data in pairs(bindingBackups)do s.write(path,data,420)end
s.write('/etc/config/mise',original,mode)
require('active-root').publish(live)
local restored=s.read('/etc/config/mise')==original
local report={passed=ok,checks=checks,system_configuration_restored=restored,old_repository_preserved=true,
 rootA=rootA,rootB=rootB,artifacts='verified archives copied to cache; SDK/library installed and probed on device',
 error=not ok and(type(err)=='table'and err.message or tostring(err))or nil}
s.write(work..'/result.json',report);print(s.json.stringify(report));os.exit(ok and restored and 0 or 1)
