-- Build a real legacy directory fixture from verified binaries and the actual
-- installed application, then use public upgrade/uninstall. No SDK is faked.
-- Private copies exist only in this test fixture, never in the new installer.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs,n=s.fs,s.nixio
local main,work=assert(arg[1]),assert(arg[2])
assert(main:find('/M5/OpenClawMgr',1,true)and fs.realpath(main)==main)
local base=main..'-legacy'
assert(not fs.lstat(base),'legacy fixture already exists; preserve and inspect it')
s.mkdir(work,448)
local manager='/usr/libexec/istorec/openclawmgr.sh'
assert(not fs.lstat('/tmp/openclawmgr-installer.lock'),'Finish the current application operation before this test')
local ref=s.decode(main..'/current/runtime.json')
local sdk=ref.storage_root..'/environments/'..ref.instance
local config_before=assert(s.read('/etc/config/openclawmgr'))
s.write(work..'/uci-before.private',config_before,384)
local checks={}
local function check(name,value)
  checks[#checks+1]={name=name,passed=not not value};s.write(work..'/result.json',{checks=checks})
  assert(value,name)
end
local function run(argv,timeout)
  local rc=s.run(argv,{output=work..'/command-private.log',timeout=timeout or 120})
  assert(rc==0,'command failed ('..rc..'): '..argv[1]..' '..tostring(argv[2]))
end
local function set(key,value)run({'/sbin/uci','set','openclawmgr.main.'..key..'='..value})end
local stopped=false
local ok,err=pcall(function()
  run({manager,'stop'})
  stopped=true
  s.mkdir(base,493);assert(fs.chmod(base,'755'))
  s.mkdir(base..'/node/bin',493)
  run({'cp','-a',sdk..'/bin/node.real',base..'/node/bin/node.real'})
  run({'cp','-a',sdk..'/lib',base..'/node/lib'})
  run({'cp','-a',ref.storage_root..'/libraries/'..ref.library,base..'/node/glibc'})
  for _,file in ipairs({'glibc-node.sh','node-loader.cjs'})do
    s.write(base..'/node/'..(file=='glibc-node.sh'and'bin/node'or file),assert(s.read('/usr/share/openclawmgr/'..file)),file=='glibc-node.sh'and 493 or 420)
  end
  assert(fs.symlink('../lib/node_modules/npm/bin/npm-cli.js',base..'/node/bin/npm'))
  run({'cp','-al',main..'/current/global',base..'/global'})
  s.mkdir(base..'/data/.openclaw',448)
  local config=s.decode(main..'/data/.openclaw/openclaw.json')
  config.gateway.port=config.gateway.port+2;config.gateway.bind='loopback'
  s.write(base..'/data/.openclaw/openclaw.json',config)
  s.write(base..'/data/M5-legacy-sentinel','legacy application data\n')
  if fs.stat(main..'/npm-cache/_cacache')then
    s.mkdir(base..'/npm-cache',448)
    run({'cp','-a',main..'/npm-cache/_cacache',base..'/npm-cache/_cacache'})
  end
  if fs.stat(main..'/npm-cache/native')then run({'cp','-a',main..'/npm-cache/native',base..'/npm-cache/native'})end
  set('base_dir',base);set('port',tostring(config.gateway.port));set('bind','loopback')
  run({'/sbin/uci','commit','openclawmgr'})
  run({manager,'start'},180)
  check('real private GNU Node legacy layout starts with authenticated health',not fs.lstat(base..'/current')and fs.stat(base..'/node/bin/node.real').size>1024*1024)
  local original_hash=s.sha(base..'/node/bin/node.real',work)
  local token_hash=s.sha(base..'/data/.openclaw/openclaw.json',work)
  run({manager,'upgrade'},4200)
  local after=s.decode(base..'/current/runtime.json')
  check('legacy upgrade binds same exact public SDK',after.instance==ref.instance and after.storage_root==ref.storage_root)
  local previous=fs.readlink(base..'/previous')
  check('private old Node retained in previous release',previous and previous:match('^releases/legacy%-')and s.sha(base..'/'..previous..'/node/bin/node.real',work)==original_hash)
  check('new release contains only Node wrappers',fs.stat(base..'/node/bin/node').size<4096 and not fs.lstat(base..'/node/glibc'))
  check('legacy data survives migration',s.read(base..'/data/M5-legacy-sentinel')=='legacy application data\n')
  check('legacy authentication/config retained',s.sha(base..'/data/.openclaw/openclaw.json',work)==token_hash)
  run({'/usr/bin/lua','/usr/share/openclawmgr/shared-runtime.lua','as-app',base,'native'},90)
  local native=s.json.parse(s.read(work..'/command-private.log'))
  check('migrated service UID uses OpenClaw vector loader',native and native.uid==n.getpw('openclawmgr').uid and native.sqliteVec and native.sqliteVec.loader=='openclaw-memory-host'and native.sqliteVec.nearestNeighbor)
  run({manager,'uninstall'},180)
  check('application uninstall removes its runtime files',not fs.lstat(base..'/releases')and not fs.lstat(base..'/node'))
  check('application uninstall retains its data',s.read(base..'/data/M5-legacy-sentinel')=='legacy application data\n')
  check('uninstall preserves shared SDK and independent application',s.decode(sdk..'/receipt.json').verified and s.decode(main..'/current/runtime.json').instance==ref.instance)
  run({main..'/node/bin/node','--version'})
  check('second caller still executes exact shared Node',s.read(work..'/command-private.log'):match('v'..ref.node:gsub('%.','%%.')))
end)
-- Restore the actual test application even when a fixture assertion fails.
if not stopped then error(err)end
s.run({'/etc/init.d/openclawmgr','stop'},{output=work..'/restore-private.log',timeout=60})
s.write('/etc/config/openclawmgr',config_before,384)
local restored=s.run({manager,'start'},{output=work..'/restore-private.log',timeout=180})
if not ok then error(err)end
check('original application restored with authenticated health',restored==0)
local report={passed=true,arch=n.uname().machine,boot_id=s.boot_id(),fixture=base,fixture_source='verified actual GNU Node and library plus actual installed OpenClaw; private copy only for legacy test',checks=checks}
s.write(work..'/result.json',report);print(s.json.stringify(report))
