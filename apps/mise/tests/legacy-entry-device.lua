-- Actual installed entry points, real persistent mount, actual managed SDK.
-- Only this test's UCI configuration is isolated; /etc/config is never changed.
local root,base=arg[1],arg[2]
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local contract=require('contract')
contract.path(root);contract.path(base)
assert(not sys.fs.lstat(base),'unique fixture directory required')
sys.mkdir(base,448)
local receipt
for _,id in ipairs(store.list(root..'/environments'))do
  local r=sys.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and r.entry.tool=='node'and r.entry.abi=='glibc'then receipt=r;break end
end
assert(receipt)
local config_before=sys.read('/etc/config/mise')
sys.mkdir(base..'/uci',448);sys.mkdir(base..'/home',448);sys.mkdir(base..'/bin',448)
sys.write(base..'/uci/mise',"config mise 'main'\n option runtime_dir '"..base.."/home'\n option acceleration '1'\n")
for _,name in ipairs({'iStoreEnhance','wget','curl'})do
  sys.write(base..'/bin/'..name,'#!/bin/sh\nprintf network-called >> "'..base..'/network-called"\nexec /bin/sleep 30\n',448)
end
-- Inspect the real ks-cli plan without installing/starting an accelerator.
sys.write(base..'/bin/ks-cli','#!/bin/sh\nprintf delegated >> "'..base..'/delegated"\nexec /usr/bin/ks-cli --explain --json "$@"\n',448)
local env={UCI_CONFIG_DIR=base..'/uci',PATH=base..'/bin:/usr/sbin:/usr/bin:/sbin:/bin',
 ISTORE_RUNTIME_HOME=base..'/home',KSPEEDER_PORT='5443',
 MISE_DATA_DIR=root..'/mise/'..receipt.entry.arch..'-glibc',MISE_CONFIG_DIR=base..'/mise-config',
 MISE_CACHE_DIR=base..'/cache',MISE_STATE_DIR=base..'/state',MISE_OFFLINE='1',
 MISE_NOT_FOUND_AUTO_INSTALL='0',MISE_HIDE_UPDATE_WARNING='1'}
local function now()local s,u=sys.nixio.gettimeofday();return s+(u or 0)/1000000 end
local results={}
local function run(name,argv,input,expected,contains)
  sys.write(base..'/stdin',input or '')
  local start=now()
  local rc=sys.run(argv,{env=env,cwd=base,stdin=base..'/stdin',output=base..'/stdout',timeout=10})
  local output=sys.read(base..'/stdout')or''
  assert(rc==expected,name..': '..rc..' '..output)
  assert(not contains or output:find(contains,1,true),name..': '..output)
  assert(not sys.fs.lstat(base..'/network-called'),'local entry probed the network')
  results[#results+1]={name=name,passed=true,exit=rc,seconds=now()-start,output=output}
end
local key='node@'..receipt.mise_key
local js=[[const a=require('node:assert/strict');a.equal(process.argv[1],'two words');a.equal(require('node:fs').readFileSync(0,'utf8'),'stdin preserved\n');a.equal(process.env.HOME,process.argv[2]);console.log(process.version);]]
run('local exec with accelerator installed and unresponsive',{'/usr/sbin/mise-istore','exec',key,'--','node','-e',js,'two words',base..'/home'},'stdin preserved\n',0,'v'..receipt.entry.version)
run('native child exit status',{'/usr/sbin/mise-istore','exec',key,'--','node','-e','process.exit(37)'},'',37)
run('interactive shell startup and nested exact SDK execution',{'/usr/sbin/mise-exec'},'/usr/sbin/mise-istore exec '..key..' -- node --version\n',0,'v'..receipt.entry.version)
run('local mise version',{'/usr/sbin/mise-istore','--version'},'',0,'2026.8.14')
assert(not sys.fs.lstat(base..'/delegated'),'local execution delegated to accelerator')
run('acquisition delegates to actual ks-cli plan without service mutation',{'/usr/sbin/mise-istore','install','node@24.22.1'},'',0,'accelerated_network')
local plan=assert(sys.decode(base..'/stdout'))
assert(plan.command[1]=='mise'and plan.command[2]=='install'and plan.command[3]=='node@24.22.1')
assert(plan.integrity_verification=='sha256_preserved')
assert(sys.read('/etc/config/mise')==config_before,'system configuration changed')
sys.write(base..'/result.json',{passed=true,scope='installed entries with isolated UCI and deliberately blocking optional network commands',results=results})
print(sys.json.stringify({passed=true,results=results}))
