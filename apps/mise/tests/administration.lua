-- Public JSON CLI checks. SDK fixtures prove metadata/deletion behavior only.
local share,root,mise,malicious=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local contract=require('contract');local artifacts=require('artifacts')
local ctx=store.open(root,true);local work=root..'/work/administration';sys.mkdir(work,448)
local count=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then io.stderr:write('FAIL '..name..' '..(type(err)=='table'and sys.json.stringify(err)or tostring(err))..'\n');os.exit(1)end
  count=count+1;print('PASS '..count..' '..name);io.stdout:flush()
end
local function cli(request,code)
  sys.write(work..'/request.json',request)
  local rc=sys.run({'/usr/bin/lua',share..'/main.lua','request'},{stdin=work..'/request.json',output=work..'/response.json',timeout=30,
    env={MISE_RUNTIME_ROOT=root,MISE_RUNTIME_MISE_BIN=mise}})
  local r=sys.decode(work..'/response.json');assert(r,'missing CLI response')
  if code then assert(rc~=0 and not r.ok and r.error.code==code,sys.json.stringify(r))else assert(rc==0 and r.ok,sys.json.stringify(r))end
  return r.value
end
local e
for _,entry in ipairs(sys.decode(share..'/catalog.json').entries)do
  if entry.tool=='node'and entry.abi=='glibc'and entry.arch==sys.nixio.uname().machine then e=entry;break end
end
local library='administration-fixture-library';local id=contract.instance_id(e,nil,library)
local sdk=root..'/environments/'..id
sys.mkdir(sdk..'/bin',493);sys.write(sdk..'/bin/node','#!/bin/sh\necho fixture-only\n',493)
local r={schema_version=1,instance=id,entry=e,npm=e.npm,library=library,artifact_set=e.artifact_set,installed_at=os.time(),verified=false,
  probes={version='fixture',arch='unknown',abi='unknown',launcher='unknown'},mise_key='istore-'..id,root=root}
sys.write(sdk..'/receipt.json',r)
sys.mkdir(root..'/libraries/'..library,493);sys.write(root..'/libraries/'..library..'/marker','preserve')
test('read shows unverified fixture without enabling unsupported adapters',function()
  local result=cli({op='read'});assert(result.online and result.runtimes[1].verified==false and result.capabilities.node.enabled==false)
end)
test('unknown JSON command rejected without state change',function()cli({op='shell',command='touch injected'},'INVALID_INPUT');assert(store.state(ctx).revision==0)end)
test('library reference blocks removal',function()cli({op='library-remove',id=library},'BUSY');assert(sys.read(root..'/libraries/'..library..'/marker')=='preserve')end)
test('installed environment blocks storage root change',function()cli({op='settings',path=root..'-changed',acceleration=false},'BUSY');assert(not sys.fs.lstat(root..'-changed'))end)
test('concurrent maintenance rejected while lock held',function()
  store.lock(ctx,{id='held'});cli({op='cache-clear'},'BUSY');store.unlock(ctx,'held')
end)
test('expired and stale public submissions rejected before worker',function()
  for _,kind in ipairs({'expired','revision'})do
    local p={schema_version=1,id='plan-'..kind,revision=kind=='revision'and 99 or 0,catalog_revision=sys.decode(share..'/catalog.json').revision,
      entry=e.id,instance=id,source='origin',created=os.time()-301,expires=os.time()-1,path=root}
    if kind=='revision'then p.created=os.time();p.expires=p.created+300 end
    sys.write(root..'/plans/'..p.id..'.json',p);cli({op='submit',id=p.id},'STALE_PLAN')
  end
  assert(#store.list(root..'/tasks')==0 and not sys.fs.lstat(root..'/.lock'))
end)
local scope=require('registration').scope(ctx,e)
sys.mkdir(scope.home,448);sys.mkdir(scope.config,448)
local env={HOME=scope.home,MISE_DATA_DIR=scope.data,MISE_CONFIG_DIR=scope.config,MISE_CACHE_DIR=scope.cache,MISE_HIDE_UPDATE_WARNING='1'}
assert(sys.run({mise,'link','node@'..r.mise_key,sdk},{env=env,output=work..'/mise.log',timeout=20})==0)
sys.write(scope.config..'/config.toml','[tools]\nnode="'..r.mise_key..'"\n')
test('public remove protects actual mise default',function()cli({op='remove',id=id},'BUSY');assert(sys.fs.stat(sdk))end)
test('public cache clear preserves SDK library and recovery material',function()
  sys.write(root..'/cache/'..string.rep('a',64),'disposable');sys.mkdir(root..'/tasks/preserved',448);sys.write(root..'/tasks/preserved/marker','recover')
  cli({op='cache-clear'});assert(#store.list(root..'/cache')==0)
  assert(sys.read(root..'/tasks/preserved/marker')=='recover'and sys.read(sdk..'/bin/node')and sys.read(root..'/libraries/'..library..'/marker'))
end)
test('explicit nondefault remove unregisters only owned SDK links',function()
  sys.write(scope.config..'/config.toml','# No default in isolated scope\n')
  local other=root..'/unrelated-sdk';sys.mkdir(other..'/bin',493);sys.write(other..'/bin/node','#!/bin/sh\necho other\n',493)
  assert(sys.run({mise,'link','node@istore-unrelated',other},{env=env,output=work..'/mise.log',timeout=20})==0)
  cli({op='remove',id=id});assert(not sys.fs.lstat(sdk)and sys.read(other..'/bin/node'))
  local path=scope.data..'/installs/node/istore-unrelated';assert(sys.fs.realpath(path)==other)
end)
test('unreferenced library can be explicitly removed',function()cli({op='library-remove',id=library});assert(not sys.fs.lstat(root..'/libraries/'..library))end)
for _,name in ipairs({'traversal','absolute','symlink-parent','symlink-chain','hardlink','fifo'})do
  test('real malicious tar rejected: '..name,function()
    local archive=malicious..'/'..name..'.tar.gz'
    local artifact={url='https://fixture.invalid/archive',sha256=string.rep('a',64),format='tar.gz',strip=1}
    local target=work..'/extract-'..name
    local ok=pcall(artifacts.extract,archive,artifact,target,work,work..'/tar.log')
    assert(not ok and not sys.fs.lstat(target),'malicious archive reached extraction')
  end)
end
print('passed='..count)
